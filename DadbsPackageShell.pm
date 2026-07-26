package DadbsPackageShell;

use DadbsUtils;

sub new
{
    my $self = bless {}, shift;
    my $scriptLocation = shift;
    my $packageDefsDir = shift;
    my $packageId = shift;
    my $packageDir = shift;
    my $buildDir = shift;
    my $installDir = shift;
    my $dadbsPackage = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDefsDir} = $packageDefsDir;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{installDir} = $installDir;
    $self->{dadbsPackage} = $dadbsPackage;

    return $self;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsPackageShell constructed for $self->{packageId}\n";
    dadbsprint "scriptLocation $self->{scriptLocation}\n";
    dadbsprint "packageDefsDir $self->{packageDefsDir}\n";
    dadbsprint "packageId $self->{packageId}\n";
    dadbsprint "packageDir $self->{packageDir}\n";
    dadbsprint "buildDir $self->{buildDir}\n";
    dadbsprint "installDir $self->{installDir}\n";
    dadbsprint "dadbsPackage $self->{dadbsPackage}\n";
}

sub startshell
{
    my $self = shift;
    my $packageId = $self->{packageId};
    dadbsprint "Package shell for $packageId\n";

    my $scriptLocation = $self->{scriptLocation};
    my $packageId = $self->{packageId};
    my $packageDirRoot = $self->{packageDir};
    my $dadbsPackageDir = ${$self->{dadbsPackage}}->{packageDir};
    my $packageDefsDir = $self->{packageDefsDir};
    my $packageDir = $packageDefsDir . "/" . $packageId;
    my $builddir = $self->{buildDir};
    my $packageBuildDir =
	$builddir .
	"/" .
	$packageId .
	"/" .
	$dadbsPackageDir;

    my $installdir = $self->{installDir};

    my $envmodifs = ${$self->{dadbsPackage}}->{envModifs};
    dadbsprint "scriptLocation is $scriptLocation\n";
    dadbsprint "packageId is $packageId\n";
    dadbsprint "packageDir is $packageDir\n";
    dadbsprint "packageBuildDir is $packageBuildDir\n";
    dadbsprint "dadbsPackageDir is $dadbsPackageDir\n";
    dadbsprint "builddir is $builddir\n";
    dadbsprint "installdir is $installdir\n";

    # Need
    # script path
    # root of dadbs (scriptLocation)
    # packageID
    # path to dibs package config
    # path to root of package build
    # install path

    my $cmd = "$scriptLocation/scripts/buildshell.sh $scriptLocation $packageId $packageDir $packageBuildDir $installdir $envmodifs";
#    dadbsprint "About to execute $cmd\n";
    if( system($cmd) != 0 )
    {
	dadbsprint "Failed during shell invocation: $!\n";
	die $!;
    }

    return 1;
}

1;
