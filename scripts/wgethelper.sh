#!/bin/sh

SCRIPTLOCATION=$1
DESTDIR=$2;
SOURCEURL=$3;
echo $SCRIPTLOCATION;
echo $DESTDIR;
echo $SOURCEURL;
cd $DESTDIR || exit -1;
# We will eventually be able to use the "/usr/dadbs/current/bin/wget",
# but for now it's not there.

# if wget cannot be made to work - potentially
# we can use curl instead
echo "NO SUPPORTED WGET HELPER YET!"
exit 1;
#wget $SOURCEURL || exit -1;
#curl -s -L -O $SOURCEURL || exit -1;

exit 0;
