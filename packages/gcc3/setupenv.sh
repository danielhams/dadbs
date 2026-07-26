# Need the built binutils in the path (for ar etc)
# This will additionally pull in any other already installed elements
# into visibility - so they must be "ready" for that.
GCC3_ROOT=$INSTALLDIR/gcc3
export GCC3_ROOT
PATH=$GCC3_ROOT/bin:$INSTALLDIR/bin:$PATH
LD_LIBRARY_PATH=$GCC3_ROOT/lib:$INSTALLDIR/lib:$LD_LIBRARY_PATH
export PATH LD_LIBRARY_PATH
CC=$INSTALLDIR/bin/$DADBS_CC
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
INSTALL="$INSTALLDIR/bin/install"
export INSTALL
