package DadbsPackageState;

use File::Basename;

use DadbsUtils;
use DadbsPackageHasher;

use constant PACKAGESTATE => qw(UNCHECKED UNFETCHED FETCHED SIGCHECKED EXTRACTED PATCHED CONFIGURED BUILT INSTALLED OUTOFDATE);

sub new
{
    my $self = bless {}, shift;
    my $verbose = shift;
    $self->{v} = $verbose;
    my $scriptLocation = shift;
    my $packageDefsDir = shift;
    my $dadbsEnvHash = shift;
    my $packageId = shift;
    my $packageDir = shift;
    my $buildDir = shift;
    my $installDir = shift;
    my $dadbsPackage = shift;
    my $foundPackageStatesRef = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{dadbsEnvHash} = $dadbsEnvHash;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{installDir} = $installDir;
    $self->{dadbsPackage} = $dadbsPackage;

    $self->{stateString} = UNCHECKED;

    my $packageDefPath = "$packageDefsDir/$packageId";
    my $packageDefFile = "$packageDefPath/$packageId.packagedef";

    my $installedFile = "$installDir/dadbsversions/$packageId.installed";
    $self->{installedFileName} = $installedFile;

    my $packageDefHash = DadbsPackageHasher::calculatePackageDefHash( $self->{v}, $packageDefPath );
    $self->{packageDefHash} = $packageDefHash;
    # Now build the "envPacDepHash" (environment, package, dependencies)
    # If this matches the value stored on the disk, this package is up
    # to date.
    # If it doesn't match, this package needs building.
    my @dependencyHashes = calculateDependencyHashes(
	$self,
	$dadbsPackage,
	$foundPackageStatesRef );

#    for( @dependencyHashes )
#    {
#	print "Found a dependency hash: $_\n";
#	exit 1;
#    }
    my $envPacDepHash = DadbsPackageHasher::calculateEnvPacDepHash(
	$dadbsEnvHash,
	$packageDefHash,
	\@dependencyHashes );

    $self->{envPacDepHash} = $envPacDepHash;

    $self->{v} && dadbsprint "Package def hash is $packageDefHash\n";
    $self->{v} && dadbsprint "Package epdh     is $envPacDepHash\n";

    if (! -e $installedFile) {
	$self->{v} && dadbsprint "Package $packageId not yet installed.\n";
	$self->{stateString} = UNFETCHED;
    }
    else {
	my $installedEnvPacDepHash = readHashFromInstalledFile($installedFile);
#	    print "Read installed envpacdephash of $installedEnvPacDepHash\n";
	if( $installedEnvPacDepHash eq $envPacDepHash ) {
	    $self->{v} && dadbsprint "Package $packageId is up to date.\n";
	    $self->{stateString} = INSTALLED;
	}
	else {
	    $self->{v} && dadbsprint "Package $packageId out of date.\n";
	    $self->{stateString} = OUTOFDATE;
	}
    }

#    $self->{v} && dadbsprint "DEBUG: State of $packageId on object $self is " .$self->{stateString} . "\n";

    return $self;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsPackageState for $self->{packageId} is $self->{stateString}\n";
}

sub setState
{
    my $self = shift;
    my $newstate = shift;
    $self->{stateString} = $newstate;
    dadbsprint "Package $self->{packageId} is now in state $newstate\n";

    if( $newstate eq INSTALLED )
    {
	my $installedFileName = $self->{installedFileName};
	dadbsprint "Creating installed file: $installedFileName\n";
	open IFN, ">$installedFileName" || die $!;
	printf IFN "$self->{envPacDepHash}\n";
	close IFN;
    }

}

sub getState
{
    my $self = shift;
    return $self->{stateString};
}

sub calculateDependencyHashes
{
    (my $self, $dadbsPackage, $foundPackageStatesRef ) = (@_);

    $self->{v} && dadbsprint "Looking for dependency hashes for $dadbsPackage->{packageId}\n";

    my @pkgDependencies = split(',',$dadbsPackage->{dependenciesList});

    my @dependencyHashes = ();

    for $dep (@pkgDependencies)
    {
	my $depPkgObj = ${$foundPackageStatesRef}{$dep};
#        $self->{v} && dadbsprint "DEBUG: reading state from $depPkgObj\n";
	my $depPkgState = $depPkgObj->getState();
	$self->{v} && dadbsprint "For dep $dep have pkgstate ".$depPkgState."\n";
	my $pkgEnvPacDepHash = $depPkgObj->{envPacDepHash};
	push @dependencyHashes, $pkgEnvPacDepHash;
#	print "Have a dep hash: " . $pkgEnvPacDepHash . "\n";
#	exit;
    }

    return @dependencyHashes;
}

sub readHashFromInstalledFile {
    my( $filename ) = (@_);

    my $contents = do{local(@ARGV,$/)=$filename;<>};
    chomp($contents);
    return $contents;
}

sub reconcileHashOnDisk {
    my $self = shift;

    # Only reconcile if it was previously installed
    if ( -f $self->{installedFileName} ) {
        my $newHash = $self->{envPacDepHash};
        if (open HFOD, ">$self->{installedFileName}") {
            print HFOD "$newHash\n";
            close HFOD;
            $self->{v} && dadbsprint "  [RECONCILE] Wrote new hash ($newHash) to $self->{installedFileName}\n";
            # Crucially: Update the state string so downstream dependencies 
            # don't falsely think this package is still OUTOFDATE.
            $self->{stateString} = INSTALLED;
            return 1; # Success
        } else {
            dadbsprint "  [ERROR] Could not open $self->{installedFileName} for writing: $!\n";
            return 0;
        }
    } else {
        $self->{v} && dadbsprint "  [RECONCILE] Skipped $self->{packageId} - no existing installation found.\n";
        return 0;
    }
}

1;
