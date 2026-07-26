#!/usr/bin/env perl
use File::Basename qw/basename/;
use FindBin;
use lib ".";
use lib "..";
#use lib "$FindBin::Bin/../lib";

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

STDERR->autoflush(1);
STDOUT->autoflush(1);

###
# TO RUN CHANGES AGAINST BOTH THE STAGE0
# AND REGULAR PACKAGES
# run with `DADBS_STAGE=STAGE0 V=1 ./bulkmodifier.pl`
# then     `V=1 ./bulkmodifier.pl`

my $verbose = 0;
$verbose = $verbose || $ENV{"V"}=="1";

sub doTheChange {
    my $packageRef = shift;
    my $packageDir = shift;
    my $packageDefFile = shift;

    my $curpkg = ${$packageRef};
    my $pkgid = $curpkg->{packageId};

    my $packageDefFile = "$packageDir/$pkgid.packagedef";

    $verbose && dadbsprint "Apply bulk transform for package '$pkgid'...\n";
    $verbose && dadbsprint "in dir $packageDir with def file $packageDefFile\n";
    dadbsprint "in dir $packageDir with def file $packageDefFile\n";
    # Example operation
#    my $cmd = "echo 'compilers=mipspro,gcc' >>$packageDefFile";
#    dadbsprint "Would execute $cmd\n";
#    system($cmd) && die $_;
}

my $scriptLocation = "..";

# For stage0
#my $packageDefsDir = "../packages/stage0";
#$ENV{"DADBS_STAGE"} = "STAGE0";

# For stage1 + regular
my $packageDefsDir = "../packages/stage0";

my $stageChecker = DadbsStageChecker->new( $scriptLocation,
					   $packageDefsDir,
					   "/tmp/builddir",
					   "/tmp/installdir" );
$stageChecker->modifyPathForCurrentStage();
$packageDefsDir = $stageChecker->getStageAdjustedPackageDefDir();

$verbose && dadbsprint "Adjusted packageDefsDir=$packageDefsDir\n";

my $pkgDependencyEngine = DadbsDependencyEngine->new($verbose,
						     $scriptLocation,
						     $packageDefsDir);

my $foundPackagesRef = $pkgDependencyEngine->listPackages();
my $p2pRef = $pkgDependencyEngine->getPackageMap();
my %pkgidToPackageMap = %{$p2pRef};

foreach $pkg (@{$foundPackagesRef})
{
    my $curpkg = ${$pkg};
    my $pkgid = $curpkg->{packageId};
    
    my $directoryOfChange = "$packageDefsDir/$pkgid";

    doTheChange($pkg, $directoryOfChange, "$pkgid.packagedef");
}

exit 0;
