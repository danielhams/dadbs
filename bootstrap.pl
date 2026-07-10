#!/usr/dadbsbootstrap/bin/perl

use File::Basename qw/basename/;
use FindBin;
#use lib ".";
use lib "$FindBin::Bin/lib";

# Packages specific to the tooling
use DadbsStageChecker;
use DadbsDependencyEngine;
use DadbsPackage;
use DadbsPackageState;
use DadbsExtractor;
use DadbsPatcher;
use DadbsConfigurator;
use DadbsBuilder;
use DadbsInstaller;
use DadbsPackageShell;
use DadbsUtils;
use DadbsDependencyWriter;

STDERR->autoflush(1);
STDOUT->autoflush(1);

my $argc = ($#ARGV + 1);
my $version = "0.1.9";

(my $configfile = basename($0)) =~ s/^(.*?)(?:\..*)?$/$1.conf/;
my $scriptLocation = $FindBin::Bin;
#dadbsprint "Script location is $scriptLocation\n";
#dadbsprint "Configfile is $configfile\n";

my $usingfoundconf = 0;

if( -e "$scriptLocation/$configfile")
{
    $usingfoundconf = 1;
    unshift(@ARGV, '@'.$scriptLocation."/".$configfile);
}

use Getopt::ArgvFile qw(argvFile);
argvFile();

use Getopt::Long;

my $packageDir = undef;
my $buildDir = undef;
my $installDir = undef;
my $dadbscompiler = "gcc";
my $verbose = 0;
my $clean = 0;
my $stoponuntested = 0;
my $dryrun = 0;
my $buildpackage = undef;
my $buildshellpackage = undef;

sub supressenv
{
    my $scriptdir = shift;
    open CFG, "<".$scriptdir."suppressenv.vars" || die $!;
    my @envvars = <CFG>;
    close CFG;

    my %values;
    foreach (@envvars) {
        chomp;
        s|#.+||;
        s|@(.+?)@|$1|g;
# this eats values with spaces in there....
#        s|\s||;
	next if $_ eq "";
	delete $ENV{$_};
	if($verbose)
	{
		dadbsprint " Supressing environment $_\n";
	}
    }
}

sub getdefaultenv
{
    my $scriptdir = shift;
    open CFG, "<".$scriptdir."defaultenv.vars" || die $!;
    my @envvars = <CFG>;
    close CFG;

    my %values;
    foreach (@envvars) {
        chomp;
        s|#.+||;
        s|@(.+?)@|$1|g;
# this eats values with spaces in there....
#        s|\s||;
	next if $_ eq "";
	my $firstEqualPos = index($_,"=");
	my $key = substr($_, 0, $firstEqualPos);
	my $val = substr($_, $firstEqualPos+1);
#	print "Found $key->$val\n";
        $values{$key} = $val;
    }
#    exit -1;
    return %values;
}

sub getoverrideenv
{
    my $scriptdir = shift;
    my $overridefile = $scriptdir."overrideenv.vars";
    if( -e $overridefile ) {
	open CFG, "<".$scriptdir."overrideenv.vars" || die $!;
	my @envvars = <CFG>;
	close CFG;

	my %values;
	foreach (@envvars) {
	    chomp;
	    s|#.+||;
	    s|@(.+?)@|$1|g;
            # this eats values with spaces in there....
#	    s|\s||;
	    next if $_ eq "";
	    my $firstEqualPos = index($_,"=");
	    my $key = substr($_, 0, $firstEqualPos);
	    my $val = substr($_, $firstEqualPos+1);
#	    print "Found $key->$val\n";
	    $values{$key} = $val;
	}
#	exit -1;
	return %values;
    }
    return {};
}

sub usage
{
    my $error = shift;
    print <<EOUSAGE
Setup: bootstrap.pl [maintenance options]
Run  : bootstrap.pl
Maintenance Options:
\t-p /pathforpackages\t--packagedir /pathforpackages
\t-b /pathforbuilding\t--builddir /pathforbuilding
\t-i /pathforinstall \t--installdir /pathforinstall
\t-v                 \t--verbose
\t                   \t--clean                (builds + installs)
\t                   \t--stoponuntested
\t                   \t--dryrun
\t                   \t--buildshell PACKAGENAME

On first run you must provide the package, build and installation directories
that this bootstrapper will use.

Dadbs bootstrap building relies on the use of a previous dadbs release
extracted and symbolically linked to '/usr/dadbs/current'.

When running the script without arguments, the script will attempt to determine
and build currently missing packages. Using the --stoponuntested flag will halt
the bootstrap process on packages that have not yet been marked as passing
their built in checks.

The first run of the script will involve bootstrapping a minimum set of
packages from which the installation packages may be built.

Configuration specified on the command line gets stored in the bootstrap.conf
file - this can be overridden by specifying the parameters a second time.
EOUSAGE
;
    exit( $error ? -1 : 0 );
}

sub writeconfig
{
    my $hash_ref = shift;
    my %hash = %{ $hash_ref };

    my $cfname = "$scriptLocation/$configfile";
    $verbose && dadbsprint "Will write config to $cfname\n";
    open(FH, '>'.$cfname) || die $!;

    foreach my $key (keys %hash)
    {
        if( $key eq "packagedir" ||
            $key eq "builddir" ||
            $key eq "installdir" ||
	    $key eq "compiler")
        {
            printf FH "--".$key . " " . $hash{$key} . "\n";
        }
#	elsif( $key eq "abi" )
#	{
#	    printf FH "--".$key . " " . $hash{$key} . "\n";
#	}
        elsif( $key eq "verbose" )
        {
            if( $hash{$key} eq 1 )
            {
                printf FH "--verbose\n";
            }
        }
        elsif( $key eq "stoponuntested" )
        {
            if( $hash{$key} eq 1 )
            {
                printf FH "--stoponuntested\n";
            }
        }
        else
        {
            dadbsprint "Unhandled option: $key\n";
            exit(-1);
        }
    }
    close(FH);
}

dadbsprint "dadbs bootstrapper script version $version\n";
dadbsprint "\n";

if( $usingfoundconf == 1 )
{
    dadbsprint "Adding found config.\n To start fresh, rm $scriptLocation/$configfile\n";
}

my %options = ();

GetOptions(\%options,
           "packagedir|p=s" => \$packageDir,
           "builddir|b=s" => \$buildDir,
           "installdir|i=s" => \$installDir,
	   "compiler|c=s" => \$dadbscompiler,
           "verbose|v" => \$verbose,
           "clean" => \$clean,
           "stoponuntested" => \$stoponuntested,
           "dryrun" => \$dryrun,
	   "build=s" => \$buildpackage,
           "buildshell=s" => \$buildshellpackage )
    or usage(true);

$verbose = $verbose || $ENV{"V"}=="1";

#if( !defined($packageDir) || !defined($buildDir) || !defined($installDir)
#    || !defined($dadbsabi))
if( !defined($packageDir) || !defined($buildDir) || !defined($installDir)
 || !defined($dadbscompiler)
  )
{
    $verbose && dadbsprint "packageDir=$packageDir\n";
    $verbose && dadbsprint "buildDir=$buildDir\n";
    $verbose && dadbsprint "installDir=$installDir\n";
    $verbose && dadbsprint "compiler=$dadbscompiler\n";
    usage(true);
}

my $compatibleDadbsCurrent = checkdadbscompatiblesetup($verbose,$dadbscompiler,$version);
if( !$compatibleDadbsCurrent )
{
    print <<EOINCOMPATIBLEDADBSCURRENT
ERROR
(1) An existing compatible dadbs release behind a symbolic link
    at /usr/dadbs/current.
Unable to continue.
EOINCOMPATIBLEDADBSCURRENT
;
    exit -1;
}


sub prompt
{
    my( $query ) = @_;
    local $| = 1;
    print $query;
    chomp(my $answer = <STDIN>);
    return $answer;
}

sub prompt_yn
{
    my( $query ) = @_;
    my $answer = prompt("$query (y/n): ");
    dadbsprint "\n";
    return lc($answer) eq 'y';
}

sub prompt_before_delete
{
    my( $dirtodelete ) = @_;
    if( $dirtodelete ne "" && $dirtodelete ne "/")
    {
	dadbsprint "About to delete $dirtodelete/*\n";
	if( prompt_yn("Are you sure") )
	{
	    system("rm -rf $dirtodelete/*");
#	    dadbsprint "rm -rf $dirtodelete/*";
	}
	else
	{
	    exit 0;
	}
    }
}

if( $clean )
{
    dadbsprint "This will delete all content...\n";
    # For now leave the packages there
#    prompt_before_delete($packageDir);
    prompt_before_delete($buildDir);
    prompt_before_delete($installDir);
    exit 0;
}

$options{"packagedir"} = $packageDir;
$options{"builddir"} = $buildDir;
$options{"installdir"} = $installDir;
$options{"compiler"} = $dadbscompiler;
$options{"verbose"} = $verbose;
$options{"stoponuntested"} = $stoponuntested;

print"\n";
if($verbose)
{
    dadbsprint "Used config: \n";
    foreach $key (keys %options)
    {
	dadbsprint " $key \t=> $options{$key}\n";
    }
}

my $onlyDryrunArguments = (($argc == 1) && ($dryrun == 1)) ? 1 : 0;
my $nonDestructiveParameters = ($onlyDryrunArguments || ($buildshellpackage ne "")) ? 1 : 0;

my $parametersUpdated = ($usingfoundconf == 0 || $argc >= 1) && ($nonDestructiveParameters == 0)
    ? 1 : 0;

if($verbose)
{
    dadbsprint "usingfoundconf=$usingfoundconf\n";
    dadbsprint "argc=$argc\n";
    dadbsprint "dryrun=$dryrun\n";
    dadbsprint "onlyDryrunArguments=$onlyDryrunArguments\n";
    dadbsprint "nonDestructiveParameters=$nonDestructiveParameters\n";
    dadbsprint "parametersUpdated=$parametersUpdated\n";
}

my $shouldWriteConfig = 0;
if( -e "$scriptLocation/$configfile" &&
    $parametersUpdated &&
    !defined($ENV{"DADBS_STAGE"}) )
{
    if( prompt_yn("This will overwrite existing config - are you sure?") )
    {
	$shouldWriteConfig = 1;
    }
    else
    {
	exit 0;
    }
}
else
{
    $shouldWriteConfig = $parametersUpdated;
}

if( $shouldWriteConfig )
{
    # Write our config back out
    writeconfig(\%options);
}
elsif($verbose)
{
    dadbsprint "Not updating configuration file\n";
}

if( $parametersUpdated )
{
    dadbsprint "\n";
    dadbsprint "Parameters updated. Now try running bootstrap.pl alone.\n";
    exit 0;
}

# Default environment vars
print"\n";
supressenv($DIR);
my(%envvars) = getdefaultenv($DIR);
foreach $var (keys %envvars)
{
    my $val = $envvars{$var};
    $verbose && dadbsprint " setting $var=$val\n";
    $ENV{$var} = $val;
}
# And an env var to allow GCC versions to reflect the dadbs version
$ENV{"DADBS_VERSION"} = $version;

# A hash of the default env, suppressed env and params for the build
my $dadbsenvhash=DadbsPackageHasher::calculateEnvHash(
    $scriptdir."defaultenv.vars",
    $scriptdir."suppressenv.vars",
    $dadbscompiler );

my(%envvars) = getoverrideenv($DIR);
foreach $var (keys %envvars)
{
    my $val = $envvars{$var};
    $verbose && dadbsprint " override of $var=$val\n";
    $ENV{$var} = $val;
}

# And set up the necessary env vars computed from
# the elfwidth,isa and compiler
my $dadbsarchcflags="";
my $dadbsarchldflags="";
my $dadbslibdir="lib";

$ENV{"DADBS_CC"}=$ENV{"DADBS_GCC_CC"};
$ENV{"DADBS_CXX"}=$ENV{"DADBS_GCC_CXX"};


$ENV{"DADBS_ARCH_CFLAGS"} = $dadbsarchcflags;
$ENV{"DADBS_ARCH_CXXFLAGS"} = $dadbsarchcflags;
$ENV{"DADBS_ARCH_LDFLAGS"} = $dadbsarchldflags;
$ENV{"DADBS_LIBDIR"} = $dadbslibdir;

if( $verbose ) {
    dadbsprint "CC            = '".$ENV{"DADBS_CC"}."'\n";
    dadbsprint "CXX           = '".$ENV{"DADBS_CXX"}."'\n";
    dadbsprint "arch CFLAGS   = '$dadbsarchcflags'\n";
    dadbsprint "arch CXXFLAGS = '$dadbsarchcflags'\n";
    dadbsprint "arch LDFLAGS  = '$dadbsarchldflags'\n";
    dadbsprint "libdir        = '$dadbslibdir'\n";
    dadbsprint "env hash      = '$dadbsenvhash'\n";
}

# Check if we need to modify paths for stage1 builds
# are already complete
my $stageChecker = DadbsStageChecker->new( $scriptLocation,
					   $packageDir,
					   $buildDir,
					   $installDir );

# Only do this once per run of the script to keep things sane
$verbose && dadbsprint "Modifying current path for this stage..\n";

# Special case - getting the /usr/dadbs/current/libXX/pkgconfig into
# the PKG_CONFIG_PATH
$ENV{"PKG_CONFIG_PATH"} = "/usr/dadbs/current/$dadbslibdir/pkgconfig";
$stageChecker->modifyPathForCurrentStage();

#my $origpath = $ENV{"PATH"};
#$ENV{"PATH"} = "$installDir/bin:$origpath";
my $origPkgCpath = $ENV{"PKG_CONFIG_PATH"};
$ENV{"PKG_CONFIG_PATH"} = "$installDir/$dadbslibdir/pkgconfig:$origPkgCpath";
$ENV{"DADBS_INSTALL_DIR"} = $installDir;

dadbsprint "Override the above by created a new file - overrideenv.vars\n";
print"\n";

my $packageDefsDir = $stageChecker->getStageAdjustedPackageDefDir();

my $pkgDependencyEngine = DadbsDependencyEngine->new($verbose,
						     $scriptLocation,
						     $packageDefsDir,
						     $dadbscompiler);

my $foundPackagesRef = $pkgDependencyEngine->listPackages();
my $p2pRef = $pkgDependencyEngine->getPackageMap();

my %pkgidToPackageMap = %{$p2pRef};

my $sapd = $stageChecker->getStageAdjustedPackageDir();
my $sabd = $stageChecker->getStageAdjustedBuildDir();
my $said = $stageChecker->getStageAdjustedInstallDir();

#dadbsprint "packageDefsDir=$packageDefsDir\n";
#dadbsprint "sapd=$sapd\n";

# Fast quit for buildshell
if( $buildshellpackage )
{
    my $bsPackage = $pkgidToPackageMap{$buildshellpackage};
    if( $bsPackage == undef)
    {
	dadbsprint "Couldn't find package $buildshellpackage.\n";
	exit -1;
    }
#    dadbsprint "Would launch build shell of $buildshellpackage here.\n";
    my $curpkgshell = DadbsPackageShell->new( $scriptLocation,
					      $packageDefsDir,
					      $buildshellpackage,
					      $packageDir,
					      $sabd,
					      $said,
					      $bsPackage );

    if( $verbose )
    {
	$curpkgshell->debug();
    }

    $curpkgshell->startshell();

    exit 0;
}

# Ensure our "dadbsversions" directory exists
if( !$dryrun )
{
    my $dadbsVersionsDir = "$installDir/dadbsversions";
    if( ! -e $dadbsVersionsDir ) {
	mkdirp("$dadbsVersionsDir") || die "Unable to create versions dir: $!";
    }
}

my %foundPackageStates = ();

# Full tree build
dadbsprint "Checking for outdated/missing packages...\n";
foreach $pkg (@{$foundPackagesRef})
{
    my $curpkg = ${$pkg};
    my $pkgid = $curpkg->{packageId};
    $verbose && dadbsprint "Checking status of package '$pkgid'...\n";

    checkPackage( $dadbsenvhash,
		  $pkg,
		  $scriptLocation,
		  $packageDefsDir,
		  $sapd,
		  $sabd,
		  $said,
		  \$pkgDependencyEngine,
		  \%foundPackageStates );
}

dadbsprint "Processed ".@{$foundPackagesRef}." packages.\n";

#if( $verbose )
#{
    my $dependenciesWriter = DadbsDependencyWriter->new($version,
							$scriptLocation,
							$foundPackagesRef,
							\%foundPackageStates);
    $dependenciesWriter->writeDependencies();
#}

exit 0;

sub checkPackage
{
    my( $dadbsenvhash,
	$pkgRef,
	$scriptLocation,
	$packageDefsDir,
	$packageDir,
	$buildDir,
	$installDir,
	$pkgDependencyEngineRef,
	$foundPackageStatesRef ) = @_;

    my $pkg = ${$pkgRef};
    my $pkgDependencyEngine = ${$pkgDependencyEngineRef};

    my($packageId) = $pkg->{packageId};
    my($curpkg) = $pkg;

    my $curpkgstate = DadbsPackageState->new($verbose,
					     $scriptLocation,
					     $packageDefsDir,
					     $dadbsenvhash,
					     $packageId,
					     $packageDir,
					     $buildDir,
					     $installDir,
					     $curpkg,
					     $foundPackageStatesRef );

#    dadbsprint "$curpkg->{passesChecksIndicator} $stoponuntested\n";
    ${$foundPackageStatesRef}{$packageId} = $curpkgstate;
    $verbose && dadbsprint "Set the package state for $packageId\n";

    my $pkgPci = $curpkg->{passesChecksIndicator};
    $verbose && dadbsprint "Package pci=$pkgPci and sou=$stoponuntested\n";

    if( !$pkgPci && !$stoponuntested)
    {
	$verbose && dadbsprint "Skipping untested package: $packageId\n";
	return;
    }

    if( $curpkgstate->getState() ne INSTALLED )
    {
	dadbsprint "Checking status of package $packageId...\n";
	# Wait for a return
	#<STDIN>;

	my $curpkgextractor = DadbsExtractor->new( $scriptLocation,
						   $packageId,
						   $packageDir,
						   $buildDir,
						   $curpkg,
						   $curpkgstate);


	if( $verbose )
	{
	    $curpkgextractor->debug();
	}

	if( !$dryrun )
	{

	    if( !$curpkgextractor->extractionSuccess() )
	    {
		$verbose && dadbsprint "Package extraction not complete.\n";
		if( !$curpkgextractor->extractit() )
		{
		    dadbsprint "Unable to extract $curpkg->{packageId}\n";
		    exit -1;
		}
	    }
	}

	my $curpkgpatcher = undef;

	if( !$dryrun )
	{
	    if( defined($curpkg->{packagePatch}) &&
		$curpkgextractor->getState() ne PATCHED)
	    {
		$curpkgpatcher = DadbsPatcher->new( $scriptLocation,
						    $packageDefsDir,
						    $packageId,
						    $packageDir,
						    $buildDir,
						    $curpkg,
						    $curpkgextractor );

		if( !$curpkgpatcher->patchit() )
		{
		    dadbsprint "Failed to patch $curpkg->{packageId}\n";
		    exit -1;
		}
		$curpkgextractor->setState(PATCHED);
	    }
	}

	my $curpkgconfigurator = DadbsConfigurator->new( $scriptLocation,
							 $packageDefsDir,
							 $packageId,
							 $packageDir,
							 $buildDir,
							 $installDir,
							 $curpkg,
							 $curpkgextractor,
							 $curpkgpatcher );


	if( !$dryrun )
	{
	    if( !$curpkgconfigurator->configureit() )
	    {
		dadbsprint "Failed during configure stage.\n";
		exit -1;
	    }
	}

	my $curpkgbuilder = DadbsBuilder->new( $scriptLocation,
					       $packageDefsDir,
					       $packageId,
					       $packageDir,
					       $buildDir,
					       $installDir,
					       $curpkg,
					       $curpkgextractor,
					       $curpkgpatcher,
					       $curpkgconfigurator );

	if( !$dryrun )
	{
	    if( !$curpkgbuilder->buildit() )
	    {
		dadbsprint "Failed during build step.\n";
		exit -1;
	    }
	}
	$verbose && dadbsprint "Package $packageId complete.\n";

	if( $stoponuntested && !($curpkg->{passesChecksIndicator}) )
	{
	    dadbsprint "This package ($packageId) is marked untested, please do the tests.\n";
	    # Only stop if we aren't dry running (pretend)
	    if( !$dryrun )
	    {
		exit 0;
	    }
	}

	my $curpkginstaller = DadbsInstaller->new( $scriptLocation,
						   $packageDefsDir,
						   $packageId,
						   $packageDir,
						   $buildDir,
						   $installDir,
						   $curpkg,
						   $curpkgextractor,
						   $curpkgpatcher,
						   $curpkgconfigurator );

	if( !$dryrun )
	{
	    if( !$curpkginstaller->installit() )
	    {
		dadbsprint "Failed during install step.\n";
		exit -1;
	    }
	    $curpkgstate->setState(INSTALLED);
	}
	else
	{
	    dadbsprint "  Package needs building...\n";
	    $curpkgstate->fakeNewInstalledDate();
	}
    }
}
