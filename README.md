# dadbs

## AMIX Development Bootstrapper

A perl script and some minimal supporting tools to allow bootstrapping of some open source tools on AMIX, preferably with a modified kernel + sufficient RAM and swap space. Lots of disk, too.

Be aware - this build process will create the exact same content that may be found in the existing dadbs releases! If you just want to "use" the software built by dadbs - just go fetch an existing dadbs release and skip this build. (See below for link).

## Needs

* AMIX 2.1c (patched) install
* Upgraded kernel to support 32mb of RAM (custom patches)
* At least 64mb of root SCSI device swap space
* Bootstrap tools (under /usr/dadbsbootstrap):
  - Perl 5.005_3 (min)
  - GNU tar (/sbin/tar) + GNU gzip
* A previously extracted dadbs release appropriate for your build >= X.X.X-amix-gcc (m68k gcc)

If you are looking for an already built dadbs release - dadbs releases are posted on the dadbs github project in the releases section [here](https://github.com/danielhams/dadbs.git/releases/).

Sorry it isn't more complete, this will be fleshed out over time.
