package DadbsExtractor;

use DadbsUtils;
use DadbsPackageState;

use File::Path qw/rmtree/;

# Contents set up from values from the dbibsPackage
#
# downloadSuccessFilePath
# 

sub new
{
    my $self = bless {}, shift;
    my $scriptLocation = shift;
    my $packageId = shift;
    my $packageDir = shift;
    my $buildDir = shift;
    my $dadbsPackage = shift;
    my $packageState = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageId} = $packageId;
    $self->{packageDir} = $packageDir;
    $self->{buildDir} = $buildDir;
    $self->{dadbsPackage} = $dadbsPackage;
    $self->{packageState} = $packageState;

    return $self;
}

sub getState
{
    my $self = shift;
    return $self->{packageState}->getState();
}

sub setState
{
    my $self = shift;
    my $newState = shift;
    $self->{packageState}->setState($newState);
}

sub extractionSuccess
{
    my $self = shift;

    return $self->getState() eq EXTRACTED;
}

sub extractit
{
    my $self = shift;

    my $destdir = $self->{packageDir}."/srcballs";
    mkdirp($destdir);
    my $destfile = $self->{dadbsPackage}->{packageFile};
    my $fulldestfile = $destdir."/".$destfile;

    if( $self->getState() ne FETCHED )
    {
        mkdirp($destdir);
        my $destfile = $self->{dadbsPackage}->{packageFile};
        my $fulldestfile = $destdir."/".$destfile;

        my $sourceurl = $self->{dadbsPackage}->{packageSource};
        my $checksum = $self->{dadbsPackage}->{packageChecksum};

        dadbsprint "Checking for already downloaded archive from $sourceurl\n";
        my $fetchcmd = $self->{scriptLocation}."/scripts/wgethelper.sh ".$self->{scriptLocation}." $destdir \"$sourceurl\"";

        # If the file exists check the signature
        my $fileexistsgood = 0;
        if( -e $fulldestfile )
        {
            if(!verifyChecksum($self,$fulldestfile,$checksum))
            {
                dadbsprint "Stale download at $fulldestfile.\n";
                dadbsprint "Removing is commented out.\n";
                exit -1;
                unlink $fulldestfile;
            }
            else
            {
		dadbsprint "File exists ($fulldestfile)\n";
                $fileexistsgood = 1;
            }
        }

        if(!$fileexistsgood)
        {
            dadbsprint "Fetching...\n";
            dadbsprint "\n\n";

            system($fetchcmd) == 0 || die $!;
            $self->setState( FETCHED );
            if(!verifyChecksum($self,$fulldestfile,$checksum))
            {
                dadbsprint "Second download attempt failed.\n";
                exit -1;
            }
        }

        # File is good
        dadbsprint "Checksum match.\n";
        $self->setState(SIGCHECKED);
    }

    if( $self->getState() == SIGCHECKED )
    {
        my $extractdir = $self->{buildDir}."/".$self->{packageId};
        dadbsprint "Removing any existing content at $extractdir\n";
        rmtree $extractdir || die $!;
        mkdirp( $extractdir );
        my $extractor = $self->{dadbsPackage}->{packageExtraction};
        my $fullpathext = $self->{scriptLocation}."/scripts/".$extractor;
        dadbsprint "Extracting to $extractdir using $fullpathext\n";
        my $cmd = "$fullpathext $extractdir $fulldestfile";
        dadbsprint "Command is $cmd\n";
        system($cmd) == 0 || die $!;

        $self->setState(EXTRACTED);
    }

    return $self->getState() == EXTRACTED;
}

sub verifyChecksum
{
    my $self=shift;
    my $filename=shift;
    my $checksum=shift;
    #    dadbsprint "Verifying checksum of $filename\n";
    
    my $calcchecksum = sumfile($self->{scriptLocation}, $filename);
    dadbsprint "Expected($checksum) - received($calcchecksum)\n";

    return $calcchecksum eq $checksum;
}

sub debug
{
    my $self = shift;
    dadbsprint "DibsExtractor constructed for $self->{packageId}\n";
    dadbsprint "Status is " . $self->getState() ."\n";
}

1;
