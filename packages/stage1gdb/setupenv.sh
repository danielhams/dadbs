# Need the built binutils + gdb in the path (for ar etc)
# This will additionally pull in any other already installed elements
# into visibility - so they must be "ready" for that.
PATH=$INSTALLDIR/bin:$PATH
LD_LIBRARY_PATH=$INSTALLDIR/lib:$LD_LIBRARY_PATH
export PATH LD_LIBRARY_PATH
CC=$DADBS_CC
CFLAGS="$DADBS_ARCH_CFLAGS"
LDFLAGS="$DADBS_ARCH_LDFLAGS"
export CC CFLAGS LDFLAGS
CXX=g++
CXXFLAGS="$DADBS_ARCH_CXXFLAGS"
export CXX CXXFLAGS
# Magical "extra" libraries flag that gdb uses
LOADLIBES="-lsocket -lnsl"
export LOADLIBES
