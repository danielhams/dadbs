CC=$DIDBS_CC
CFLAGS="$DIDBS_ARCH_CFLAGS"
LDFLAGS="$DIDBS_ARCH_LDFLAGS"
LIBS=""
#export CC CFLAGS LDFLAGS PATH LIBS
#PATH="$INSTALLDIR/bin:$EXTRAARGS/bin:$PATH"
export CC CFLAGS LDFLAGS LIBS

#LD_LIBRARY_PATH="$INSTALLDIR/lib:$LD_LIBRARY_PATH"
#PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:$PKG_CONFIG_PATH"
#export LD_LIBRARY_PATH PKG_CONFIG_PATH

# Unset CONFIG_SHELL which this version of make's "configure" script doesn't
# seem to be happy with.
unset CONFIG_SHELL

# To debug
#echo "In setupenv.sh - PATH is $PATH"
#echo "In setupenv.sh - LD_LIBRARY_PATH is $LD_LIBRARY_PATH"
#echo "In setupenv.sh - SHELL is $SHELL"
#echo "In setupenv.sh - CONFIG_SHELL is $CONFIG_SHELL"

#echo "Env is:"
#env
#exit 1
