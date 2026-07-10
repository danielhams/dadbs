# dadbs

## AMIX Development Bootstrapper

A perl script and some minimal supporting tools to allow bootstrapping of some open source tools on AMIX, preferably with a modified kernel + sufficient RAM and swap space. Lots of disk, too.

Be aware - this build process will create the exact same content that may be found in the existing dadbs releases! If you just want to "use" the software built by dadbs - just go fetch an existing dadbs release and skip this build. (See below for link).

## Needs

* AMIX 2.1c (patched) install
* Upgraded kernel to support 64mb of RAM (custom patches)
* At least 64mb of root SCSI device swap space
* Bootstrap tools (under /usr/dadbsbootstrap):
  - Perl 5.005_3 (min)
  - GNU tar (/sbin/tar) + GNU gzip
* A previously extracted dadbs release appropriate for your build >= X.X.X-amix-gcc (m68k gcc)

If you are looking for an already built dadbs release - dadbs releases are posted on the dadbs github project in the releases section [here](https://github.com/danielhams/dadbs.git/releases/).

Suggested approach:

(1) Do everything as your user, I do not recommend use of root or installing into /usr/local or other existing directories. If you have to do things as root, I consider that a bug!

(Example for n32, mips3, gcc)
```
* As root
* Create /usr/dadbs
* chown myser /usr/dadbs
* chgrp other /usr/dadbs
* As your user
* Extract previous dadbs release
* cd /usr/dadbs; tar xf usr-dadbs-X.X.X-m68kgcc.tar.gz
* Link up a "current"
* cd /usr/dadbs; ln -s X_X_X_m68k_gcc current
* (Setup paths to include the bin and lib of the above)
* cd ~; git clone https://github.com/danielhams/dadbs.git
* cd ~/dadbs
* echo "DADBS_JOBS=1" >overrideenv.vars
* For above, set the DADBS_JOBS to 1. No SMP on AMIX :-)
* ./bootstrap.pl -p /usr/dadbs/X_X_package -b /usr/dadbs/0_*_*_m68k_gcc_build -i /usr/dadbs/0_*_*_m68k_gcc -a m68k -c gcc # (replace * - this sets up paths)
* ./bootstrap.pl # (This builds the stage1 then release packages)
```

## Using the installed tools

You'll need to setup your environment to pull the right directories (bash example):

```
* export PATH=/usr/dadbs/0_*_*_m68k_gcc/bin:$PATH
* export LD_LIBRARY_PATH=/usr/dadbs/0_*_*_m68k_gcc/lib32:$LD_LIBRARYN32_PATH
* export PKG_CONFIG_PATH=/usr/dadbs/0_*_*_m68k_gcc/lib32/pkgconfig:$PKG_CONFIG_PATH

GCC2.95.3 is now included within the regular `bin` and `lib` directories - no additional PATH or LD_LIBRARY_PATH entries required.
```

## Troubleshooting

### Solutions To Problems

The currently known list of issues when building dadbs can be found under the github "issues" section. Hopefully with workarounds for the problems found.

eof
