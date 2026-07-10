package DadbsBuilder;

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

sub buildit
{
    my $self = shift;
    my $packageId = $self->{packageId};
    dadbsprint "Building $packageId\n";

    my $builddir = "$self->{buildDir}/$self->{packageId}/$self->{dadbsPackage}->{packageDir}";
    my $installdir = $self->{installDir};
    dadbsprint "Would build in $builddir\n";
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

    my $buildRecipe = "$self->{packageDefsDir}/$self->{packageId}/$self->{dadbsPackage}->{buildRecipe}";
    my $cmd = "$buildRecipe $builddir $installdir $extraargs";
    dadbsprint "About to execute $cmd\n";
    if( system($cmd) != 0 )
    {
	dadbsprint "Failed during build: $!\n";
	die $!;
    }

    return 1;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsBuilder constructed for $self->{packageId}\n";
}

1;
