package DadbsUtils;
use POSIX;
use Exporter;
use IO::Handle;
use Cwd 'abs_path';

use Time::HiRes qw(gettimeofday);

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
    # This should use the md5sum from current path
    $dsum = "md5sum";

    my $digest = `$dsum $filename`;
    chomp($digest);

#    dadbsprint "Digest result is $digest\n";
    (my $extracteddigest = $digest ) =~ s/^(\S+)\s+.*$/$1/g;
#    dadbsprint "Pulled out $extracteddigest\n";

    return $extracteddigest;
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
# (2) That the underlying directory is version >= 0.1.3 < current version
# (3) That the gcc we expect is present (needs to be dadbs built 2.95.3 due to Motorola ABI compatibility)
sub checkdadbscompatiblesetup
{
    my $retVal=1;
    my $verbose=shift;
    my $dadbscompiler=shift;
    my $version=shift;
    
    # Just exit with error for now, we'll fix the generational checks once
    # we have a stable generation to check on.
    dadbsprint "Current compatability checking is broken and needs fixing...";
    return $retVal;
    my($scriptMajVer,$scriptGenVer,$scriptMinVer) =
	    $version =~ m/(\d)\.(\d)\.(\d)(.*)/;
    $verbose && dadbsprint "Checking for /usr/dadbs/current symbolic link..";
    my $linkIsOk = (-e '/usr/dadbs/current' && -l '/usr/dadbs/current');
    $verbose && print "$linkIsOk\n";
    $retVal = $retVal && $linkIsOk;
    if( !$linkIsOk ) {
	return $retVal;
    }
    $verbose && dadbsprint "Checking underlying dir is compatible version..";
    my $dirBehindLink = abs_path('/usr/dadbs/current');
    my $dirIsOk=0;
    if( defined($dirBehindLink) && -e $dirBehindLink ) {
	$verbose && dadbsprint "dirBehindLink is $dirBehindLink\n";
	my($dirMajVer,$dirGenVer,$dirMinVer,$dirRest) =
	    $dirBehindLink =~ m/(\d)_(\d)_(\d)[^_]*(_.+)/;
	$verbose && dadbsprint "Matched $dirMajVer $dirGenVer $dirMinVer $dirRest\n";
	my $expectedWidthIsaCompiler = "_n32_mips3_" . 
	    ($dadbscompiler eq "gcc" ? "gcc" : "mp");
	if( rindex($dirRest,$expectedWidthIsaCompiler) == 0 ) {
	    $verbose && dadbsprint "Elf width, ISA, Compiler OK\n";
	    # Version check min is 0.1.7 (starting from 0.1.7)
	    # due to the need for a particular dadbs perl version.
	    # max is current script minus one
	    if( ($dirMajVer > 0)
		||
		($dirGenVer > 1)
		||
		($dirMinVer >= 7 ) ) {
#		dadbsprint "Min version check ok\n";
		# Check the version is less or the same
		if( ($dirMajVer < $scriptMajVer)
		    ||
		    ($dirMajVer == $scriptMajVer && $dirGenVer < $scriptGenVer)
		    ||
		    ($dirMajVer == $scriptMajVer && $dirGenVer == $scriptGenVer && $dirMinVer <= $scriptMinVer ) ) {
#		    dadbsprint "Max version check ok\n";
		    $dirIsOk=1;
		}
		else {
		    $verbose && dadbsprint "Max version test failure!\n";
		}
	    }
	    else {
		$verbose && dadbsprint "Min version test failure!\n";
	    }
	}
    }
    $verbose && print "$dirIsOk\n";
    $retVal = $retVal && $dirIsOk;
    if( !$dirIsOk ) {
	return $retVal;
    }
    # Final check, is it really dadbs there...
    # Check there are gccs under the right dirs
    $verbose && dadbsprint "Checking for needed gccs..";
    my $gccsAreOk=0;
    if(
	-e '/usr/dadbs/current/bin/gcc'
	) {
	$gccsAreOk=1;
    }
    $verbose && print "$gccsAreOk\n";
    $retVal = $retVal && $gccsAreOk;
    return $retVal;
}

1;
