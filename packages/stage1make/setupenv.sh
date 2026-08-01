export CC="$DADBS_CC"
export CFLAGS="$DADBS_ARCH_CFLAGS"
# For debugging
#export CFLAGS="-g -O0"
export LDFLAGS="$DADBS_ARCH_LDFLAGS"
export LIBS=""

# Unset CONFIG_SHELL which this version of make's "configure" script doesn't
# seem to be happy with.
#unset CONFIG_SHELL

#echo "Env is:"
#env
#exit 1
