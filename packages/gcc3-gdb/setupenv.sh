# Use the previous generation dadbs gcc3 to build by
# ensure that the gcc3 paths are at the front
GCC3_ROOT=$INSTALLDIR/gcc3
export GCC3_ROOT
PATH=$GCC3_ROOT/bin:$REAL_BOOT_ROOT/gcc3/bin:$PATH
LD_LIBRARY_PATH=$GCC3_ROOT/lib:$REAL_BOOT_ROOT/gcc3/lib:$LD_LIBRARY_PATH
export PATH LD_LIBRARY_PATH
#CC=$DADBS_CC
CC="gcc"
CFLAGS="$DADBS_ARCH_CFLAGS"
LDFLAGS="$DADBS_ARCH_LDFLAGS"
export CC CFLAGS LDFLAGS
XX=g++
CXXFLAGS="$DADBS_ARCH_CXXFLAGS"
export CXX CXXFLAGS
# Magical "extra" libraries flag that gdb uses
LOADLIBES="-lsocket -lnsl"
export LOADLIBES
