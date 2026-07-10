package DadbsDependencyEngine;

use DadbsUtils;

sub new
{
    my $self = bless{}, shift;
    my $verbose = shift;
    $self->{v} = $verbose;
    my $scriptLocation = shift;
    my $packageDefsDir = shift;
    my $dadbsCompiler = shift;

    $self->{scriptLocation} = $scriptLocation;
    $self->{packageDefsDir} = $packageDefsDir;

    $self->findPackages($dadbsCompiler);

    return $self;
}

sub findPackages
{
    my $self = shift;
    my $dadbsCompiler = shift;
    my $packageLocation = "$self->{packageDefsDir}";
    if( ! -e $packageLocation )
    {
	dadbsprint "Unable to find packages at $packageLocation\n";
	exit 1;
    }
    dadbsprint "Looking for packages in $packageLocation\n";

    # Glob is _slightly_ quicker, and saves a "fork/exec", too
#    my @FOUNDPKGS = `ls $packageLocation/*/*.packagedef`;
    my @FOUNDPKGS = glob "$packageLocation/*/*.packagedef";

    dadbsprint "Completed package search of $packageLocation\n";

    chomp(@FOUNDPKGS);
    if( length(@FOUNDPKGS) == 0 )
    {
	dadbsprint "Unable to find packages at $packageLocation\n";
	exit 1;
    }
#    dadbsprint "Have @FOUNDPKGS\n";
    my @knownPackages = ();

    dadbsprint "Reading package definitions...\n";

    foreach $foundpkg (@FOUNDPKGS)
    {
	(my $pkgname = $foundpkg) =~ s/.*\/.+\/(\S+)\.packagedef.*/$1/;
	my $dpkg = DadbsPackage->new($self->{v},$pkgname);
	$dpkg->readPackageDef($self->{scriptLocation},
	    $packageLocation);
	$dpkg->debug();
	if( (!$dpkg->{disabled}) && index($dpkg->{compilers}, $dadbsCompiler) != -1 )
	{
	    push(@knownPackages, \$dpkg);
	}
	else
	{
	    my $pkgid = $dpkg->{packageId};
	    $self->{v} && dadbsprint "Skipping disabled package '$pkgid'\n";
	}
    }

    $self->{knownPackages} = \@knownPackages;

    my %pidToPackage = ();

    foreach $pkg (@{$self->{knownPackages}})
    {
	my $pkgid = ${$pkg}->{packageId};
#	dadbsprint "DE - Have a package '$pkgid'\n";
	$pidToPackage{$pkgid} = $pkg;
    }

    $self->{pidToPackage} = \%pidToPackage;
    my %donePackages;

    dadbsprint "Computing package dependencies and order...\n";

    my $orderedRef = flattenAndSortDeps( \@knownPackages, \%pidToPackage, \%donePackages );
    if( $self->{v} )
    {
	dadbsprint "Package order as follows:\n";
	foreach $pkg (@{$orderedRef})
	{
	    my $curpkg = ${$pkg};
	    my $pkgid = $curpkg->{packageId};
	    my $sequenceNo = $curpkg->{sequenceNo};
	    my $dependencies = $curpkg->{dependenciesList};
	    dadbsprint "Package: $pkgid => $sequenceNo\t\t($dependencies)\n";
	}
    }

    $self->{knownPackages} = $orderedRef;

    dadbsprint "Completed package dependencies and order...\n";
}

sub listPackages
{
    my $self = shift;
    return $self->{knownPackages};
}

sub getPackageMap
{
    my $self = shift;
    return $self->{pidToPackage};
}

sub packageInResolutionStack
{
    my $pkgResolutionStackRef = shift;
    my $pkgId = shift;

    my %params = map { $_ => 1 } @{$pkgResolutionStackRef};

    return exists($params{$pkgId});
}

sub flattenAndSortDeps
{
    my $knownPkgsRef = shift;
    my $p2pRef = shift;
    my $donepRef = shift;

    # Set up deps
    for $pkgref (@{$knownPkgsRef})
    {
	my @pkgResolutionStack=();
	recursiveFlattenDeps( $pkgref,
			      $knownPkgsRef,
			      $p2pRef,
			      $donepRef,
			      $pkgref,
	                      \@pkgResolutionStack );

#	dadbsprint "One done.\n";
#	foreach $pkgid (keys %{$donepRef})
#	{
#	    dadbsprint "Done package: $pkgid\n";
#	}
    }

    # Sort (first on seq no, then on package ID)
    my @ordered = sort {
	${$a}->{sequenceNo} <=> ${$b}->{sequenceNo}
	||
	${$a}->{packageId} cmp ${$b}->{packageId}
    } @{$knownPkgsRef};

    # If having problem with dependency ordering
    # Uncomment this stuff to see what order is being used.
#    dadbsprint "Sorted packages:\n";
#    foreach $sortedpkgref (@ordered)
#    {
#	my $pkg = ${$sortedpkgref};
#	dadbsprint "Seq: $pkg->{sequenceNo}\t:\t $pkg->{packageId} \n";
#    }
#    exit;

    return \@ordered;
}

sub recursiveFlattenDeps
{
    my $drivingPkgRef = shift;
    my $knownPkgsRef = shift;
    my $p2pRef = shift;
    my $donepRef = shift;
    my $curpkgRef = shift;
    my $pkgResolutionStackRef = shift;

    my @knownPackages = @{$knownPkgsRef};
    my %pidToPackage = %{$p2pRef};
    my %donePackages = %{$donepRef};
    my $curPkg = ${$curpkgRef};

    my $curPkgId = $curPkg->{packageId};
#    dadbsprint "RecursiveFlattenDeps of $curPkgId\n";

    # Check if already handled
    if( ${$donepRef}{$curPkgId} ne "" )
    {
#	dadbsprint "Package $curPkgId is already complete.\n";
	return $curPkg->{sequenceNo};
    }

    # Check if package is already in the resolution stack
    # which means circular dependencies somewhere
    if( packageInResolutionStack( $pkgResolutionStackRef,
				  $curPkgId ) )
    {
	dadbsprint "Dependency cycle detected with driving pkg: ".
	    ${$drivingPkgRef}->{packageId} . "!\n";
	foreach $deppkgid (@{$pkgResolutionStackRef})
	{
	    dadbsprint "Pkgid: $deppkgid\n";
	}
	exit 1;
    }
    push @{$pkgResolutionStackRef}, $curPkgId;
    
    # For each dependency, find and add their dependencies
    my $deps = $curPkg->{dependenciesList};

#    dadbsprint "For package $curPkgId dependencies are $deps\n";

    my @depIds = split(',',$deps);
    my $sequenceNo = 0;

    foreach $depId (@depIds)
    {
	my $depRef = ${$p2pRef}{$depId};
	if( !defined($depRef) )
	{
	    dadbsprint "Missing dependency: $depId for $curPkgId\n";
	    exit 1;
	}
	my $childSeqNo = recursiveFlattenDeps( $drivingPkgRef,
					       $knownPkgsRef,
					       $p2pRef,
					       $donepRef,
					       $depRef,
					       $pkgResolutionStackRef );

	my $tmpSeqNo = $childSeqNo + 1;

	if( $tmpSeqNo > $sequenceNo )
	{
	    $sequenceNo = $tmpSeqNo;
	}
    }

    $curPkg->{sequenceNo} = $sequenceNo;

    ${$donepRef}{$curPkgId} = "done";
    ${$pkgsInCurrentResolveRef}{$curPkgId} = "done";
#    dadbsprint "Setting package $curPkgId as done\n";
    pop @{$pkgResolutionStackRef};

    return $curPkg->{sequenceNo};
}

1;
