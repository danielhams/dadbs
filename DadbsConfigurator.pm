package DadbsConfigurator;

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

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDefsDir} = $packageDefsDir;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{installDir} = $installDir;
    $self->{dadbsPackage} = $dadbsPackage;
    $self->{dadbsExtractor} = $dadbsExtractor;
    $self->{dadbsPatcher} = $dadbsPatcher;

    return $self;
}

sub configureit
{
    my $self = shift;
    my $packageId = $self->{packageId};
    dadbsprint "Configuring $packageId\n";

    my $builddir = "$self->{buildDir}/$packageId/$self->{dadbsPackage}->{packageDir}";
    dadbsprint "Would configure in $builddir\n";
    my $installdir = $self->{installDir};
    my $extraargs;
#    dadbsprint "Checking if $packageId begins with stage1.\n";
#    if( begins_with($packageId,"stage1") )
#    {
#	$extraargs="/usr/dadbs/current";
#    }
#    else
#    {
	$extraargs=$self->{scriptLocation};
#    }
    my $packageDefDir = $self->{packageDefsDir} . "/" . $packageId;
    dadbsprint "Changing directory to $packageDefDir\n";
    chdir $packageDefDir;

    my $configureRecipe = "$self->{packageDefsDir}/$packageId/$self->{dadbsPackage}->{configureRecipe}";
    my $cmd = "$configureRecipe $builddir $installdir $extraargs";
    dadbsprint "About to execute $cmd\n";
    system($cmd) == 0 || die $!;

    return 1;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsConfigurator constructed for $self->{packageId}\n";
}

1;
