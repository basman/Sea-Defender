my $missile_speed   = 0.25;	# constant; units: distance/second
my $pboatX_L        = 0.08;	# constant
my $pboatY_L        = 0.25;	# varies with sea level
my $pboatX_R	    = 1.52;	# constant
my $pboatY_R        = 0.25;	# varies with sea level
my $missiles_left_L = 10;	# reloaded upon wave_start
my $missiles_left_R = 10;	# reloaded upon wave_start

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
	#TODO
	print STDERR "r1=$runlength1\n";
    }

    if(defined $runlength2 && ($runlength2 < 0 || $runlength2 > $dist_TD)) {
	# either no collision possible or too late (after hitting the torpedo's target)
	$runlength2 = undef;
	$x2 = undef;
	$y2 = undef;
    } elsif(defined $runlength2) {
	# calculate target coordinates by (xT,yT) and runlength
	#       using gradient of (T-D)
	#TODO
	print STDERR "r2=$runlength2\n";
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

    my ($X, $Y, $runlength, $side);
    for(my $i=0; $i < 4; $i++) {
	# initialize or choose shorter interception
	if((!defined $runlength && defined $runlengths[$i]) || 
	    defined $runlengths[$i] && $runlengths[$i] < $runlength) {
	    $X = $Xs[$i];
	    $Y = $Ys[$i];
	    $runlength = $runlengths[$i];
	    $side = $i < 2 ? 'l' : 'r';
	}
    }

    if(!defined $runlength) {
	print STDERR "FATAL: no solution found!\n";
		print STDERR "   -- solution input: T($fromX,$fromY) D($toX,$toY) Tspeed=$torpedo_speed; M0($pboatX_L,$pboatY_L) M1($pboatX_R,$pboatY_R) Mspeed=$missile_speed\n";
    }

    print STDERR "<<  target $X,$Y; side='$side'\n";

    return ($X, $Y, $side);
}

sub fire($$$) {
    my ($x, $y, $side) = @_;
    if($side eq 'l' || $side eq '0') {
	$missiles_left_L--;
    } else {
	$missiles_left_R--;
    }
    printf "fire $side $x,$y\n"; 
}


my $posX = 0.318869;
my $posY = 1.1;
my $toX = 0.4961;
my $toY = 0.25;
my %params = ('velocity' => 0.052);

my ($solutionX, $solutionY, $side) = fire_solution($posX, $posY, $toX, $toY, $params{velocity});
fire($solutionX, $solutionY, $side);

