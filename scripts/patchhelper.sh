#!/usr/bin/env sh

DESTDIR=$1;
PATCHFILE=$2;
echo $DESTDIR;
echo $PATCHFILE;
cd $DESTDIR || exit -1;
patch -p0 -Z <$PATCHFILE || exit -1;
exit 0;
