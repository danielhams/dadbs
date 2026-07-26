#!/usr/bin/env bash

# Clear out current environment first
unset PKG_CONFIG_PATH
unset LDFLAGS
unset CFLAGS
unset CPPFLAGS
unset CXXFLAGS
unset PERL
unset M4
unset SED
unset GREP
unset BISON
unset YACC
unset SHELL
unset SHELL_PATH
unset CONFIG_SHELL
unset LD_LIBRARY_PATH
unset GCC_ROOT
unset CC
unset CXX
unset LD
unset AR
unset RANLIB
unset HOST
unset GNUTC_HOME

#export DADBS_CURRENT=/usr/dadbs/current
#export PATH=$DADBS_CURRENT/bin:/usr/local/bin:/usr/bin:/usr/sbin:/usr/ccs/bin:/sbin:/usr/sbin:/etc:/usr/ucb:/usr/amiga/bin:/usr/public/bin
#export LD_LIBRARY_PATH=$DADBS_CURRENT/lib:/usr/local/lib:/usr/lib:/usr/amiga/lib:/usr/public/lib

export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/usr/ccs/bin:/sbin:/usr/sbin:/etc:/usr/ucb:/usr/amiga/bin:/usr/public/bin
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/usr/amiga/lib:/usr/public/lib
echo "Set PATH=$PATH"
echo "Set LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

export PS1='[isolshell \u@\h \W]\$ '
exec /usr/dadbs/0.1.0/bin/bash --norc -i
