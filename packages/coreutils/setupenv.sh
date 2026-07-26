CC=$DADBS_CC
CFLAGS="$DADBS_ARCH_CFLAGS"
LDFLAGS="$DADBS_ARCH_LDFLAGS"
export CC CFLAGS LDFLAGS
NO_INSTALL_PROGS="arch,hostname,su,chcon,pinky,stty,sha224sum,sha256sum,sha384sum,sha512sum,dd"
export NO_INSTALL_PROGS
