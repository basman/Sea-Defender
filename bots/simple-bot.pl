#!/usr/bin/perl -w
#
# Simple bot:
#	- launches missiles immediately upon receipt of a torpedo message
#	- pboat side is picked by shortest missile distance and missiles
#	  available
#	- goes for every torpedo, even if it would hit the water (needs to
#	  keep track of sunken ships)
#	- no internal timing
#	- no multi-hit strategy
#       - step 1: don't fire two missiles, if one will hit two torpedoes
#       - step 2: launch delay to wait for torpedoes' crossing point to match
#             	  missile target point
#
#	- does not take into account that torpedoes can be hit at any point
#	  within their shape
#

use IO::Socket;
use strict;

$|=1;

our $serverHostname = 'localhost';
our $serverPort     = 2101;

my $missile_speed   = 0.25;	# constant; units: distance/second
my $pboatX_L        = 0.08;	# constant
my $pboatY_L        = 0.25;	# varies with sea level
my $pboatX_R	    = 1.52;	# constant
my $pboatY_R        = 0.25;	# varies with sea level
my $missiles_left_L = 10;	# reloaded upon wave_start
my $missiles_left_R = 10;	# reloaded upon wave_start

my $lead_offset	    = 0.05;	# aim for the head of torpedoes

my $gameServer;

# ==========   SUB ROUTINES   ===========

# calculate distance between two points
sub distance($$$$) {
    my ($x1,$y1,$x2,$y2) = @_;
    return sqrt(($x1-$x2)**2 + ($y1-$y2)**2);
}

# calculate one angle of a triangle with given lengths of all sides
# return: cosine of the angle opposite to the first parameter (length of side 'a')
sub cos_alpha($$$) {
    my ($a,$b,$c) = @_;
    return ($b**2 + $c**2 - $a**2) / (2*$b*$c);
}

# calculate two solutions for torpedos' runlength until interception point
sub torpedo_intercept_runlengths($$$$) {
    my ($cos_AoB, $dist_TM, $vT, $vM) = @_;

    if($cos_AoB**2 - (1-($vM/$vT)**2) < 0) {
	# no real (rational or irrational) solution, if the radicant (sqrt below) is negative
	return (undef, undef);
    }

    my $termA = $dist_TM*$cos_AoB;
    my $termB = $dist_TM*sqrt($cos_AoB**2 - (1-($vM/$vT)**2));
    my $termC = 1-($vM/$vT)**2;

    return (
	($termA + $termB) / $termC,
	($termA - $termB) / $termC
    );
}

# compute point on line T-D with distance $runlength to T and lying between T and D
sub project_point($$$$$) {
    my ($xT,$yT, $xD,$yD, $runlength) = @_;
    my ($x,$y);

    my $dist_TD = distance($xT,$yT, $xD,$yD);

    $x = $xT + ($xD-$xT)/$dist_TD*$runlength;
    $y = $yT + ($yD-$yT)/$dist_TD*$runlength;

    return ($x,$y);
}

# aim a bit in front of torpedo's centre
sub lead_correction($$$$) {
    my ($fromX,$fromY, $toX,$toY) = @_;
    return project_point($fromX,$fromY, $toX,$toY, $lead_offset);
}

sub intercept_points($$$$$$$$) {
    # T: torpedo launch position; D: torpedo destination; M: missile launch position
    # vT: torpedo speed; vM: missile speed
    my ($xT,$yT, $xD,$yD, $xM,$yM, $vT,$vM) = @_;
    my ($x1,$y1,$runlength1,$x2,$y2,$runlength2); # result array

    # calculate both runlengths (if any)
    my $dist_TM = distance($xT,$yT,$xM,$yM);
    my $dist_TD = distance($xT,$yT,$xD,$yD);
    my $dist_MD = distance($xM,$yM,$xD,$yD);
    my $cos_AoB = cos_alpha($dist_MD,$dist_TM,$dist_TD);

    # gradient of line T-D
    my $m_TD = ($yD-$yT) / ($xD-$xT);

    ($runlength1, $runlength2) = torpedo_intercept_runlengths($cos_AoB, $dist_TM, $vT, $vM); 
    if(defined $runlength1 && ($runlength1 < 0 || $runlength1 > $dist_TD)) {
	# either no collision possible or too late (after hitting the torpedo's target)
	$runlength1 = undef;
	$x1 = undef;
	$y1 = undef;
    } elsif(defined $runlength1) {
	# calculate target coordinates by (xT,yT) and runlength
	#       using gradient of (T-D)
	($x1,$y1) = project_point($xT,$yT, $xD,$yD, $runlength1);
    }

    if(defined $runlength2 && ($runlength2 < 0 || $runlength2 > $dist_TD)) {
	# either no collision possible or too late (after hitting the torpedo's target)
	$runlength2 = undef;
	$x2 = undef;
	$y2 = undef;
    } elsif(defined $runlength2) {
	# calculate target coordinates by (xT,yT) and runlength
	#       using gradient of (T-D)
	($x2,$y2) = project_point($xT,$yT, $xD,$yD, $runlength2);
    }

    return ($x1,$y1,$runlength1, $x2,$y2,$runlength2);
}

sub fire_solution($$$$$) {
    my ($fromX, $fromY, $toX, $toY, $torpedo_speed) = @_;

    #print STDERR "fire_solution: from $fromX,$fromY to $toX,$toY; speed=$torpedo_speed\n";

    # calculate intercept points for both pboats (up to 4 solutions)
    my @Xs;
    my @Ys;
    my @runlengths;
    ($Xs[0], $Ys[0], $runlengths[0], $Xs[1], $Ys[1], $runlengths[1]) =
	intercept_points($fromX,$fromY,$toX,$toY,$pboatX_L,$pboatY_L,$torpedo_speed,$missile_speed);
    ($Xs[2], $Ys[2], $runlengths[2], $Xs[3], $Ys[3], $runlengths[3]) =
	intercept_points($fromX,$fromY,$toX,$toY,$pboatX_R,$pboatY_R,$torpedo_speed,$missile_speed);

    my ($X, $Y, $bestdistance, $side);
    for(my $i=0; $i < 4; $i++) {
	# pick the corresponding pboat side
	my $cur_side = $i < 2 ? 'l' : 'r';

	# pick the corresponding launch position
	my ($xM,$yM) = $i < 2 ? ($pboatX_L,$pboatY_L) : ($pboatX_R,$pboatY_R);
	# calculate missile distance only once within this loop
	my $distance;
	if(defined $Xs[$i] && defined $Ys[$i]) {
	    $distance = distance($Xs[$i],$Ys[$i], $xM,$yM);
	}

	# fetch corresponding missiles_left value
	my $missiles_left = $i < 2 ? $missiles_left_L : $missiles_left_R;

	# initialize or with 70% chance choose shorter interception
	if(((!defined $bestdistance && defined $runlengths[$i]) || 
	    (defined $runlengths[$i] && $bestdistance > $distance &&
	    rand() < 0.7)) &&
	    $missiles_left > 0) {
	    $X = $Xs[$i];
	    $Y = $Ys[$i];
	    $bestdistance = distance($Xs[$i],$Ys[$i], $xM,$yM);
	    $side = $cur_side;
	}
    }

    if(!defined $bestdistance) {
	print STDERR "FATAL: no solution found!\n";
		print STDERR "   -- solution input: T($fromX,$fromY) D($toX,$toY) Tspeed=$torpedo_speed; M0($pboatX_L,$pboatY_L) M1($pboatX_R,$pboatY_R) Mspeed=$missile_speed\n";
    } else {
	print STDERR "<<  target $X,$Y; side='$side'\n";
    }

    return ($X, $Y, $side);
}

sub fire($$$) {
    my ($x, $y, $side) = @_;
    if($side eq 'l' || $side eq '0') {
	$missiles_left_L--;
    } else {
	$missiles_left_R--;
    }
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
	($posX, $posY) = lead_correction($posX,$posY, $toX,$toY);
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
    } else {
	print ">>RAW '$rawmsg'\n";
    }
}

# ==========   MAIN ROUTINE   ===========

if($#ARGV >= 0) {
	$serverHostname = $ARGV[0];
}
if($#ARGV >= 1) {
	$serverPort = $ARGV[1];
}

print STDERR "connecting...";
my $retries = 30;
my @stati = qw(- \ | /);
while(! ($gameServer = IO::Socket::INET->new(
	Proto    => 'tcp',
	PeerAddr => $serverHostname,
	PeerPort => $serverPort
)) && --$retries >= 0) {
	print STDERR "\b";
	print STDERR $stati[$retries % scalar @stati];
	sleep(1);
}
print STDERR "\n";
die "connection failed: $!" unless $gameServer;

print STDERR "connected.\n";

while(<$gameServer>) {
    chomp $_;
    receive($_);
}


