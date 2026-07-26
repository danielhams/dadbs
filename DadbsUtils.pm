package DadbsUtils;
use POSIX;
use Exporter;
use IO::Handle;
use Cwd 'abs_path';

use Time::HiRes qw(gettimeofday);

use Digest::MD5;

@ISA = ('Exporter');
@EXPORT=('mkdirp','sumfile','begins_with','dadbsprint','checkdadbscompatiblesetup');

use File::Basename;

# Tweak to 1 to see date/time output
my $useTimestamps=1;

sub dadbsprint
{
    my @args = @_;
    if($useTimestamps) {
	my @ts = gettimeofday();
	my $microst = $ts[1] %1000000;
	my $millis = floor($microst/1000);
	my $micros = $microst%1000;
#	my $subsecstr = sprintf ".%0.3d.%0.3d", $millis, $micros;
	my $subsecstr = sprintf ".%0.3d", $millis;
	print strftime("%Y-%m-%d %T",localtime) . $subsecstr . " ";
    }
    print @args;
}

sub mkdirp($)
{
    my $dir=shift;
    return if( -d $dir );
    mkdirp(dirname($dir));
    mkdir $dir, 0755 || die $!;
}

sub sumfile
{
    my $scriptLocation=shift;
    my $filename=shift;

    open FH, "<".$filename || die "dadbs: Cannot open '$filename' for hashing: $!";
    binmode(FH);
    my $ctx = Digest::MD5->new;
    $ctx->addfile(FH);
    my $digest = $ctx->hexdigest;
    close FH;
    return $digest;
}

sub begins_with
{
    return substr($_[0], 0, length($_[1])) eq $_[1];
}

# Verify that:
# We have an existing dadbs versions is installed and available
# as /usr/dadbs/current
# So we verify that
# (1) /usr/dadbs/current _is_ a symbolic link
# (2) That the underlying directory exists
# (3) That the gcc we expect is present (needs to be dadbs built 2.95.3 due to Motorola ABI compatibility)
sub checkdadbscompatiblesetup
{
    my ($verbose, $compiler, $version) = @_;
    
    # 1. Check for the symlink (the scaffold entry point)
    my $boot_link = '/usr/dadbs/current';
    unless (-l $boot_link) {
        dadbsprint "Error: $boot_link is missing or not a symlink.\n";
        return 0;
    }

    # 2. Resolve it to ensure it's not a dangling link
    my $real_path = abs_path($boot_link);
    unless (defined $real_path && -d $real_path) {
        dadbsprint "Error: $boot_link resolves to a non-existent directory.\n";
        return 0;
    }

    # 3. Sanity check for the toolchain
    unless (-x "$real_path/bin/gcc") {
        dadbsprint "Error: No GCC found in $real_path/bin. Scaffold is broken.\n";
        return 0;
    }

    $verbose && dadbsprint "Scaffold verified at $real_path\n";
    return 1;
}

1;
