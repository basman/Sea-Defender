#!/usr/bin/perl -w
#
# Simple bot:
#	- launches missiles immediately upon receipt of a torpedo message
#	- pboat side is always the same as side of torpedo's launch position
#	- does not care about remaining missiles per pboat
#	- goes for every torpedo, even if it would hit the water
#	- no internal timing
#	- no multi-hit strategy
#

use IO::Socket;
use strict;

our $serverHostname = 'localhost';
our $serverPort     = 2101;

my $missile_speed   = 0.25;	# constant; units: distance/second
my $pboatX_L        = 0.08;	# constant
my $pboatY_L        = 0.25;	# varies with sea level
my $pboatX_R	    = 1.52;	# constant
my $pboatY_R        = 0.25;	# varies with sea level
my $missiles_left_L = 10;	# reloaded upon wave_start
my $missiles_left_R = 10;	# reloaded upon wave_start

my $gameServer;

# ==========   SUB ROUTINES   ===========

sub fire_solution($$$$$) {
    my ($fromX, $fromY, $toX, $toY, $torpedo_speed) = @_;

    #print STDERR "fire_solution: from $fromX,$fromY to $toX,$toY; speed=$torpedo_speed\n";

    my $fireX = abs($toX-$fromX)/2;
    my $fireY = abs($toY-$fromY)/2;
    my $side  = $fromX < 0.5 ? 'l' : 'r';

    print STDERR "<<  target $fireX,$fireY; side='$side'\n";

    return ($fireX, $fireY, $side);
}

sub fire($$$) {
    my ($x, $y, $side) = @_;
    printf $gameServer "fire $side $x,$y\n"; 
}

sub receive($) {
    my $rawmsg = shift;

    my ($time, $posX, $posY, $event, $param_str) = $rawmsg =~ /^([\d.]+) ([^,]+),(\S+) (\S+) (.*)/;

    if(!$time) {
	die "message parse error: '$rawmsg'";
    }

    my @parList = split(/ /, $param_str);
    my %params;
    foreach my $s (@parList) {
	my ($k,$v) = split(/=/, $s);
	$params{$k} = $v;
    }

    if($event eq "launch_torpedo") {
	print ">> torpedo launch at $posX,$posY target=$params{target} speed=$params{velocity}\n";

	my ($toX, $toY) = split(/,/, $params{target}, 2);
	my ($solutionX, $solutionY, $side) = fire_solution($posX, $posY, $toX, $toY, $params{velocity});
	fire($solutionX, $solutionY, $side);
    } elsif($event eq 'missiles_reloaded' || $event eq 'missile_fired') {
	if($posX < 0.5) {
	    $missiles_left_L = $params{missiles_left};
	} else {
	    $missiles_left_R = $params{missiles_left};
	}
    } elsif($event eq 'missile_fired') {
	print ">> missile_fired at $posX,$posY to $params{destination}, radius=$params{radius}\n";
    }
}

# ==========   MAIN ROUTINE   ===========

if($#ARGV >= 0) {
	$serverHostname = $ARGV[0];
}
if($#ARGV >= 1) {
	$serverPort = $ARGV[1];
}

$gameServer = IO::Socket::INET->new(
	Proto    => 'tcp',
	PeerAddr => $serverHostname,
	PeerPort => $serverPort
) or die "connection failed: $!";

print STDERR "connected.\n";

while(<$gameServer>) {
    chomp $_;
    receive($_);
}


