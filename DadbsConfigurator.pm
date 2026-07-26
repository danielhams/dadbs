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

    my $rootbuilddir = "$self->{buildDir}/$packageId";
    if(!-d $rootbuilddir) {
	die "Missing expected directory '$rootbuilddir' as target: $!\n";
    }
    my $outputlogfile = "$rootbuilddir/configure.log";

    my $builddir = "$rootbuilddir/$self->{dadbsPackage}->{packageDir}";
    dadbsprint "Configuring in $builddir...\n";
    my $installdir = $self->{installDir};
    my $extraargs;
    $extraargs=$self->{scriptLocation};
    my $packageDefDir = $self->{packageDefsDir} . "/" . $packageId;
    dadbsprint "Changing directory to $packageDefDir\n";
    chdir $packageDefDir;

    my $configureRecipe = "$self->{dadbsPackage}->{configureRecipe}";
    my $cmd = "./$configureRecipe $builddir $installdir $extraargs 1>$outputlogfile 2>&1";
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
