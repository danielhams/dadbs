package DadbsPatcher;

use DadbsUtils;

use File::Copy qw/cp/;

sub new
{
    my $self = bless {}, shift;
    my $scriptLocation = shift;
    my $packageDefsDir = shift;
    my $packageId = shift;
    my $packageDir = shift;
    my $buildDir = shift;
    my $dadbsPackage = shift;
    my $dadbsExtractor = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDefsDir} = $packageDefsDir;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{dadbsPackage} = $dadbsPackage;
    $self->{dadbsExtractor} = $dadbsExtractor;

    return $self;
}

sub patchit
{
    my $self = shift;

    my $sl = $self->{scriptLocation};
    my $patchfn = $self->{dadbsPackage}->{packagePatch};
    my $fullpathpatch = "$self->{packageDefsDir}/$self->{packageId}/$patchfn";
    my $patchdest = "$self->{buildDir}/$self->{packageId}";
    dadbsprint "Copying patch file $fullpathpatch to $patchdest\n";
    cp($fullpathpatch,$patchdest) || die $!;

    my $patchcmd = "$sl/scripts/patchhelper.sh $patchdest $patchfn";
    dadbsprint "patch command is $patchcmd\n";
    system($patchcmd) == 0 || die $!;

    return 1;
}

sub debug
{
    my $self = shift;
    dadbsprint "DadbsPatcher constructed for $self->{packageId}\n";
}

1;
