#!/usr/bin/env perl

# Ensure we're warned about missing/unused variables
use strict;

use File::Basename qw/dirname basename/;
use File::Path qw/rmtree/;
use FindBin;
#use lib ".";
use lib "$FindBin::Bin/lib";

use Cwd qw(abs_path);

# Packages specific to the tooling
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

use constant true        => 1;
use constant false       => 0;

STDERR->autoflush(1);
STDOUT->autoflush(1);

my $argc = ($#ARGV + 1);
my $version = "0.2.0";

(my $configfile = basename($0)) =~ s/^(.*?)(?:\..*)?$/$1.conf/;
my $scriptLocation = $FindBin::Bin;
dadbsprint "Script location is $scriptLocation\n";
dadbsprint "Configfile is $configfile\n";

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
my $updatehashes = 0;
my $preservebuilddirs = 0;
my $buildpackage = undef;
my $buildshellpackage = undef;

sub debug_env {
    my($env_stage) = shift;
    # Debug env 1
    if( $verbose ) {
	dadbsprint "$env_stage - DEBUG OF ENV AFTER SUPPRESS/DEFAULT/OVERRIDE:\n";
	foreach my $var (keys %ENV) {
	    dadbsprint "  $var = $ENV{$var}\n";
	}
    }
}

sub load_env_file {
    my ($file, $is_mandatory) = @_;
    unless (-e $file) {
        die "DADBS Error: Mandatory environment file '$file' missing.\n" if $is_mandatory;
        return (); # Return empty list for optional files
    }

    open(ENVFH, "<$file") or die "DADBS Error: Cannot open '$file': $!\n";
    my %file_vars;
    while (<ENVFH>) {
        chomp;
        s/#.*//;            # Strip comments
        s/^\s+//; s/\s+$//; # Trim whitespace
        next if /^$/;       # Skip empty lines

        if (index($_, '=') != -1) {
            my ($key, $val) = split(/=/, $_, 2);
            $file_vars{$key} = $val;
        } else {
            # For suppression, a key with no '=' is just the key name
            $file_vars{$_} = 1;
        }
    }
    close(ENVFH);
    return %file_vars;
}

sub get_abs_file_path {
    my $path = shift;
    my $dir = dirname($path);
    my $file = basename($path);
    my $real_dir = abs_path($dir) || $dir;
    return "$real_dir/$file";
}

sub evaluate_environment
{
    my ($is_stage1, $installDir, $static_env_href) = @_;

    # 1. Reset env to static baseline
    %ENV = %{$static_env_href};

    # 2. Resolve phsyical roots
    my $raw_boot_root = $ENV{'DADBS_BOOT_ROOT'} || "/usr/dadbs/current";
    my $real_boot_root = abs_path($raw_boot_root) || $raw_boot_root;
    my $real_inst_root = abs_path($installDir) || $installDir;

    # 3. Work out PATH/LD_LIBRARY_PATH/PKG_CONFIG_PATH
    my $base_path = $ENV{'PATH'} || "";
    my $base_ld   = $ENV{'LD_LIBRARY_PATH'} || "";
    my $base_pkg  = $ENV{'PKG_CONFIG_PATH'} || "";

    if ($is_stage1) {
        $ENV{'PATH'} = "$real_boot_root/bin" . ($base_path ? ":$base_path" : "");
        $ENV{'LD_LIBRARY_PATH'} = "$real_boot_root/lib" . ($base_ld ? ":$base_ld" : "");
        $ENV{'PKG_CONFIG_PATH'} = "$real_boot_root/lib/pkgconfig" . ($base_pkg ? ":$base_pkg" : "");
    } else {
        $ENV{'PATH'} = "$real_inst_root/bin" . ($base_path ? ":$base_path" : "");
        $ENV{'LD_LIBRARY_PATH'} = "$real_inst_root/lib" . ($base_ld ? ":$base_ld" : "");
        $ENV{'PKG_CONFIG_PATH'} = "$real_inst_root/lib/pkgconfig" . ($base_pkg ? ":$base_pkg" : "");
    }

    # 4. Resolve the Post-Eval templates
    foreach my $key (keys %ENV) {
        if ($key =~ /^(.*)_POST_EVAL$/) {
            my $target_var = $1;
            my $val = $ENV{$key};

            $val =~ s/\$DADBS_BOOT_ROOT/$real_boot_root/g;
            $val =~ s/\$DADBS_INSTALL_ROOT/$real_inst_root/g;
            # Add any other template substitutions here

            if ($is_stage1 && $target_var =~ /^(.+)_BOOT$/) {
                # e.g., SHELL_BOOT_POST_EVAL becomes SHELL
                $ENV{$1} = get_abs_file_path($val) || $val;
            } 
            elsif (!$is_stage1 && $target_var !~ /_BOOT$/) {
                # e.g., SHELL_POST_EVAL becomes SHELL
                $ENV{$target_var} = get_abs_file_path($val) || $val;
            }

	    # Clean up raw template var so it doesn't leak
	    delete $ENV{$key};
        }
    }

    # 5. Boot tool variables eval
    if (my $tools = $ENV{'DADBS_BOOT_TOOLS'}) {
        foreach my $tool (split /,/, $tools) {
            my $bin_path = "$real_boot_root/bin/$tool";
            $ENV{"DADBS_BOOT_" . uc($tool)} = get_abs_file_path($bin_path) || $bin_path;
        }
    }
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
\t                   \t--dryrun-updatehashes
\t                   \t--preserve-builddirs
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
           "dryrun-updatehashes" => \$updatehashes,
	   "preserve-builddirs" => \$preservebuilddirs,
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
    foreach my $key (keys %options)
    {
	dadbsprint " $key \t=> $options{$key}\n";
    }
}

# If we are in "updatehashes" mode - we are "dryrunning" too
if( $updatehashes ) {
    dadbsprint "WARNING: This will update on-disk hash correlation.\n";
    if( !prompt_yn("Are you sure") ) {
	exit 0;
    }	
    $dryrun = 1;
}

my $onlyDryrunArguments = (($argc == 1) && ($dryrun == 1)) ? 1 : 0;
my $isTransient = ($dryrun || $updatehashes || $preservebuilddirs) ? 1 : 0;
my $nonDestructiveParameters = ($isTransient || ($buildshellpackage ne "")) ? 1 : 0;

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
# And an env var to allow GCC versions to reflect the dadbs version
$ENV{"DADBS_VERSION"} = $version;

# A hash of the default env, suppressed env and params for the build
my $dadbsenvhash=DadbsPackageHasher::calculateEnvHash(
    $scriptLocation."/defaultenv.vars",
    $scriptLocation."/suppressenv.vars",
    $dadbscompiler );

# A. Clear the deck (Mandatory)
my %to_suppress = load_env_file($scriptLocation . "/suppressenv.vars", 1);
foreach my $var (keys %to_suppress) {
    delete $ENV{$var};
}

# B. Load Defaults (Mandatory)
my %defaults = load_env_file($scriptLocation . "/defaultenv.vars", 1);
foreach my $var (keys %defaults) {
    $ENV{$var} = $defaults{$var};
}

# C. Apply Overrides (Optional)
my %overrides = load_env_file($scriptLocation . "/overrideenv.vars", 0);
foreach my $var (keys %overrides) {
    $ENV{$var} = $overrides{$var};
}

# D. Final static tweaks (System-wide constants)
$ENV{"DADBS_VERSION"} = $version;
$ENV{"DADBS_CC"}      = $ENV{"DADBS_GCC_CC"}; # Bridging old/new names
$ENV{"DADBS_CXX"}     = $ENV{"DADBS_GCC_CXX"};

# Capture
my(%static_env) = %ENV;

#debug_env("initial-load");

if( $verbose ) {
    dadbsprint "CC            = '".$ENV{"DADBS_CC"}."'\n";
    dadbsprint "CXX           = '".$ENV{"DADBS_CXX"}."'\n";
    dadbsprint "env hash      = '$dadbsenvhash'\n";
}

dadbsprint "Override the above by creating/populating overrideenv.vars\n";
print"\n";

my $packageDefsDir = "packages";

my $pkgDependencyEngine = DadbsDependencyEngine->new($verbose,
						     $scriptLocation,
						     $packageDefsDir,
						     $dadbscompiler);

my $foundPackagesRef = $pkgDependencyEngine->listPackages();
my $p2pRef = $pkgDependencyEngine->getPackageMap();

my %pkgidToPackageMap = %{$p2pRef};

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

    # Ensure we get the "right" shell env, too
    my $is_stage1 = begins_with($buildshellpackage, "stage1");
    debug_env("before-eval");
    evaluate_environment($is_stage1, $installDir, \%static_env);
    debug_env("after-eval");

    my $curpkgshell = DadbsPackageShell->new( $scriptLocation,
					      $packageDefsDir,
					      $buildshellpackage,
					      $packageDir,
					      $buildDir,
					      $installDir,
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

if(!$installDir) {
    die "Failed to have a valid installDir - $installDir\n";
}

# Full tree build
dadbsprint "Checking for outdated/missing packages...\n";
foreach my $pkg (@{$foundPackagesRef})
{
    chdir $scriptLocation || die "Cannot return to root: $!";

    my $curpkg = ${$pkg};
    my $pkgid = $curpkg->{packageId};
    $verbose && dadbsprint "Checking status of package '$pkgid'...\n";

    my $is_stage1 = begins_with($pkgid, "stage1");
    evaluate_environment($is_stage1, $installDir, \%static_env);

    checkPackage( $dadbsenvhash,
		  $pkg,
		  $scriptLocation,
		  $packageDefsDir,
		  $packageDir,
		  $buildDir,
		  $installDir,
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
    my $discoveredState = ${$foundPackageStatesRef}{$packageId}->getState();
    $verbose && dadbsprint "$packageId discovered package state is $discoveredState\n";

    my $pkgPci = $curpkg->{passesChecksIndicator};
    $verbose && dadbsprint "Package pci=$pkgPci and sou=$stoponuntested\n";

    if( !$pkgPci && !$stoponuntested)
    {
	$verbose && dadbsprint "Skipping untested package: $packageId\n";
	return;
    }

    if( $curpkgstate->getState() ne "INSTALLED" )
    {
	dadbsprint "Checking extraction status of uninstalled package $packageId...\n";
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
		$curpkgextractor->getState() ne "PATCHED")
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
		$curpkgextractor->setState("PATCHED");
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
	$verbose && dadbsprint "Check of package $packageId complete.\n";

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

	if( !$dryrun ) {
	    if( !$curpkginstaller->installit() ) {
		dadbsprint "Failed during install step.\n";
		exit -1;
	    }
	    $curpkgstate->setState("INSTALLED");
            my $srcdir = $buildDir."/".$packageId."/".$curpkg->{packageDir};
            if( !$preservebuilddirs ) {
                if( $packageId ne "" && $curpkg->{packageDir} ne "" && -d $srcdir) {
		    dadbsprint "  [CLEAN] Removing temporary source directory: $srcdir ...\n";
		    rmtree($srcdir) || die "Unable to remove source tree for $packageId($srcdir): $!\n";
		}
                else {
                    dadbsprint "  [ERROR] - packageId=".$packageId." packageDir=".$curpkg->{packageDir}." and srcdir=".$srcdir."\n";
                    exit -1;
                }
            }
            else {
                dadbsprint "  [PRESERVE] Leaving source for inspection at $srcdir\n";
            }
	}
        else {
	    # In a dryrun
	    if( $updatehashes ) {
                if( $curpkgstate->reconcileHashOnDisk() ) {
		    dadbsprint "  Hash reconciled on disk for $packageId.\n";
		}
            }
	}
    }
    # Wait for a return so I can debug what is going on with
    # weird package states.
    #<STDIN>;
}
