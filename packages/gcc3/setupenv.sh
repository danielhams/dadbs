# Need the built binutils in the path (for ar etc)
# This will additionally pull in any other already installed elements
# into visibility - so they must be "ready" for that.
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
CXX=g++
CXXFLAGS="$DADBS_ARCH_CXXFLAGS"
export CXX CXXFLAGS
# CFLAGS used in gcc3 build stages / processes
BOOT_CFLAGS="-Os"
CFLAGS_FOR_TARGET="-Os"
STAGE1_CFLAGS="-Os"
LIBGCC2_DEBUG_CFLAGS=""
export BOOT_CFLAGS CFLAGS_FOR_TARGET STAGE1_CFLAGS LIBGCC2_DEBUG_CFLAGS
