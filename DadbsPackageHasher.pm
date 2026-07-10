package DadbsPackageHasher;

use Digest::SHA;
use File::Basename;

use DadbsUtils;

sub new
{
    my $self = bless{}, shift;
    my $verbose = shift;
    $self->{v} = $verbose;

    return $self;
}

sub calculateEnvHash
{
    my ($envFile, $supEnvFile, $compiler) = (@_);

    # Compute a sha1 sum of the contents of the package def dir
    my $envSha = Digest::SHA->new("sha1");
    $envSha->addfile($envFile);
    $envSha->addfile($supEnvFile);
    $envSha->add($compiler);
    return $envSha->b64digest;
}

sub calculatePackageDefHash
{
    my ($verbose, $packageDefDir) = (@_);

    # Compute a sha1 sum of the contents of the package def dir
    my $packageSha = Digest::SHA->new("sha1");
    my @PKGFILES = glob "$packageDefDir/*";
    chomp(@PKGFILES);
    for (@PKGFILES)
    {
	# I use emacs, it creates backup files named FILENAME~
	next if (m/.*\~$/);
	my $pkgHelperFile = basename($_);
	$packageSha->addfile($packageDefDir."/".$pkgHelperFile);
    }
#    (!$verbose) && print "#";

    return $packageSha->b64digest;
}

sub calculateEnvPacDepHash
{
    my ($envHash, $packageDefHash, $dependencyHashesRef) = (@_);
    my $packageSha = Digest::SHA->new("sha1");

    $packageSha->add($envHash);
    $packageSha->add($packageDefHash);
    for( @{$dependencyHashesRef} )
    {
	$packageSha->add($_);
    }

    return $packageSha->b64digest;
}

1;
