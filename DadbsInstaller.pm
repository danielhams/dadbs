package DadbsInstaller;

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
    my $dadbsExtractor = shift;
    my $dadbsPatcher = shift;
    my $dadbsConfigurator = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDefsDir} = $packageDefsDir;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{installDir} = $installDir;
    $self->{dadbsPackage} = $dadbsPackage;
    $self->{dadbsExtractor} = $dadbsExtractor;
    $self->{dadbsPatcher} = $dadbsPatcher;
    $self->{dadbsConfigurator} = $dadbsConfigurator;

    return $self;
}

sub installit
{
    my $self = shift;
    my $packageId = $self->{packageId};
    dadbsprint "Installing $packageId\n";

    my $builddir = "$self->{buildDir}/$self->{packageId}/$self->{dadbsPackage}->{packageDir}";
    my $installdir = $self->{installDir};
    dadbsprint "Build is in $builddir\n";
    my $extraargs;
    if( begins_with($packageId,"stage1") )
    {
	$extraargs="/usr/dadbs/current";
    }
    else
    {
	$extraargs="";
    }
    my $packageDefDir = $self->{packageDefsDir} . "/" . $packageId;
    dadbsprint "Changing directory to $packageDefDir\n";
    chdir $packageDefDir;

    my $installRecipe = "$self->{packageDefsDir}/$self->{packageId}/$self->{dadbsPackage}->{installRecipe}";
    my $cmd = "$installRecipe $builddir $installdir $extraargs";
    dadbsprint "About to execute $cmd\n";
    system($cmd) == 0 || die $!;

    return 1;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsInstaller constructed for $self->{packageId}\n";
}

1;
