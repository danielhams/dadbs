package DadbsStageChecker;

use DadbsUtils;

use constant PACKAGESTAGE => qw(BUILD);

sub new
{
    my $self = bless {}, shift;
    my $scriptLocation = shift;
    my $packageDir = shift;
    my $buildDir = shift;
    my $installDir = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{installDir} = $installDir;

    # Check to see what certain "stage" files exist

    my $stageEnvString = $ENV{"DADBS_STAGE"};
    $self->{stageString} = defined($stageEnvString) ? $stageEnvString : "BUILD";

    $self->{missingStageString} = $self->calcMissingStage();

    dadbsprint "Setting missing stage to $self->{missingStageString}\n";

    return $self;
}

sub getStageAdjustedPackageDir
{
    my $self = shift;
    return $self->{packageDir};
}

sub getStageAdjustedBuildDir
{
    my $self = shift;
    return $self->{buildDir};
}

sub getStageAdjustedInstallDir
{
    my $self = shift;
    return $self->{installDir};
}

sub getStageAdjustedPackageDefDir()
{
    my $self = shift;
    return "$self->{scriptLocation}/packages";
}

sub calcMissingStage
{
    # We rely on a previous dadbs release now for "stage0" binaries
    return undef;
}

sub stagesMissing
{
    my $self = shift;

    return defined($self->{missingStageString});
}

sub prependEnvVarPath
{
    my $self = shift;
    my $envVarName = shift;
    my $extraPath = shift;

    my $prevValue = $ENV{$envVarName};
    if( !defined($prevValue) )
	{
	    $ENV{$envVarName} = $extraPath;
	}
	else
	{
	    $ENV{$envVarName} = $extraPath . ":" . $prevValue;
	}
    my $newValue = $ENV{$envVarName};

    dadbsprint "Reset $envVarName from $prevValue to $newValue\n";
}

sub modifyPathForCurrentStage
{
    my $self = shift;
    my $envRef = shift;
    dadbsprint "Modifying path for stage '$self->{stageString}' ...\n";

    my $extraBinPath = $self->getStageAdjustedInstallDir() . "/bin";
    $self->prependEnvVarPath("PATH", $extraBinPath);
    my $extraLibPath;
    my $extraPkgConfigPath;

    $extraLibPath = $self->getStageAdjustedInstallDir() . "/lib";
    $self->prependEnvVarPath("LD_LIBRARY_PATH", $extraLibPath);
    $extraPkgConfigPath = $self->getStageAdjustedInstallDir() . "/lib/pkgconfig";
    $self->prependEnvVarPath("PKG_CONFIG_PATH", $extraPkgConfigPath);
}

1;
