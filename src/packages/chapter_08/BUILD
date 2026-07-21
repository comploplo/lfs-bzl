"""
Chapter 8: Building the Final System

This chapter builds ~80 packages in phases:
- Phase 2: Core Foundation (18 packages)
- Phase 3: Toolchain & Security (16 packages)
- Phase 4: Build System & Python (25 packages)
- Phase 5: System Services (20 packages)
- Phase 6: Final Packages (2 packages)

Critical path: glibc -> binutils -> gcc -> everything else
Test dependencies: gcc and coreutils tests require :shadow (for tester user)
"""

load("//tools:lfs_macros.bzl", "lfs_configure_make")
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

###############################################################################
# Toolchain Definition
###############################################################################

lfs_toolchain(
    name = "toolchain",
    bin_path = "/usr/bin:/usr/sbin:/bin:/sbin",
    env = {
        "CC": "gcc",
        "CXX": "g++",
    },
    deps = [":gcc"],
)

###############################################################################
# PHASE 2: Core Foundation (18 packages)
###############################################################################

# 1. Man-pages - Data files only
# NOTE: Depends on chapter_07 to ensure chroot environment is ready
lfs_package(
    name = "man_pages",
    srcs = ["@man_pages_src//file"],
    build_cmd = "true",
    configure_cmd = "rm -v man3/crypt*",
    install_cmd = "make -R GIT=false prefix=/usr install",
    phase = "chroot",
    deps = ["//packages/chapter_07"],
)

# 2. Iana-Etc - Data files only
lfs_package(
    name = "iana_etc",
    srcs = ["@iana_etc_src//file"],
    build_cmd = "true",
    configure_cmd = "true",
    install_cmd = "cp services protocols /etc",
    phase = "chroot",
    deps = [":man_pages"],
)

# 3. Glibc - C library (CRITICAL - requires tests)
# Expected test failures: io/tst-lchmod (chroot), nss/tst-nss-files-hosts-multi (timeout)
lfs_package(
    name = "glibc",
    srcs = [
        "@glibc_src//file",
        "@tzdata_src//file",
    ],
    build_cmd = "cd build && make",
    configure_cmd = """
        mkdir -v build
        cd build
        echo "rootsbindir=/usr/sbin" > configparms
        ../configure --prefix=/usr \\
            --disable-werror \\
            --enable-kernel=5.4 \\
            --enable-stack-protector=strong \\
            --disable-nscd \\
            libc_cv_slibdir=/usr/lib
    """,
    install_cmd = """
        cd build
        touch /etc/ld.so.conf
        sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
        make install
        sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

        # Install locales (minimal set for testing)
        localedef -i C -f UTF-8 C.UTF-8
        localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
        localedef -i de_DE -f ISO-8859-1 de_DE
        localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
        localedef -i de_DE -f UTF-8 de_DE.UTF-8
        localedef -i el_GR -f ISO-8859-7 el_GR
        localedef -i en_GB -f ISO-8859-1 en_GB
        localedef -i en_GB -f UTF-8 en_GB.UTF-8
        localedef -i en_HK -f ISO-8859-1 en_HK
        localedef -i en_PH -f ISO-8859-1 en_PH
        localedef -i en_US -f ISO-8859-1 en_US
        localedef -i en_US -f UTF-8 en_US.UTF-8
        localedef -i es_ES -f ISO-8859-15 es_ES@euro
        localedef -i es_MX -f ISO-8859-1 es_MX
        localedef -i fa_IR -f UTF-8 fa_IR
        localedef -i fr_FR -f ISO-8859-1 fr_FR
        localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
        localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
        localedef -i is_IS -f ISO-8859-1 is_IS
        localedef -i is_IS -f UTF-8 is_IS.UTF-8
        localedef -i it_IT -f ISO-8859-1 it_IT
        localedef -i it_IT -f ISO-8859-15 it_IT@euro
        localedef -i it_IT -f UTF-8 it_IT.UTF-8
        localedef -i ja_JP -f EUC-JP ja_JP
        localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
        localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
        localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
        localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
        localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
        localedef -i se_NO -f UTF-8 se_NO.UTF-8
        localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
        localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
        localedef -i zh_CN -f GB18030 zh_CN.GB18030
        localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
        localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

        # Configure nsswitch.conf
        cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

        # Install timezone data (find tarball path from sources list)
        TZDATA_TAR=$(grep tzdata "$LFS_PKG_SRCS_FILE")
        tar -xf "$TZDATA_TAR"
        ZONEINFO=/usr/share/zoneinfo
        mkdir -pv $ZONEINFO/{posix,right}
        for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
            zic -L /dev/null   -d $ZONEINFO       ${tz}
            zic -L /dev/null   -d $ZONEINFO/posix ${tz}
            zic -L leapseconds -d $ZONEINFO/right ${tz}
        done
        cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
        zic -d $ZONEINFO -p America/New_York
        unset ZONEINFO

        ln -sfv /usr/share/zoneinfo/UTC /etc/localtime

        # Configure dynamic loader
        cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
    """,
    patches = ["@glibc_fhs_patch//file"],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":iana_etc"],
)

# 4. Zlib - Compression library
lfs_package(
    name = "zlib",
    srcs = ["@zlib_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = """
        make install
        rm -fv /usr/lib/libz.a
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":glibc"],
)

# 5. Bzip2 - Compression library
lfs_package(
    name = "bzip2",
    srcs = ["@bzip2_src//file"],
    build_cmd = """
        make -f Makefile-libbz2_so
        make clean
        make
    """,
    configure_cmd = """
        sed -i 's@\\(ln -s -f \\)$(PREFIX)/bin/@\\1@' Makefile
        sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    """,
    install_cmd = """
        make PREFIX=/usr install
        cp -av libbz2.so.* /usr/lib
        ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
        ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
        cp -v bzip2-shared /usr/bin/bzip2
        for i in /usr/bin/{bzcat,bunzip2}; do
            ln -sfv bzip2 $i
        done
        rm -fv /usr/lib/libbz2.a
    """,
    patches = ["@bzip2_docs_patch//file"],
    phase = "chroot",
    deps = [":glibc"],
)

# 6. Xz - Compression library
lfs_configure_make(
    name = "xz",
    srcs = ["@xz_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--disable-static",
        "--docdir=/usr/share/doc/xz-5.8.2",
    ],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":glibc"],
)

# 7. Lz4 - Fast compression library
lfs_package(
    name = "lz4",
    srcs = ["@lz4_src//file"],
    build_cmd = "make BUILD_STATIC=no PREFIX=/usr",
    configure_cmd = "true",
    install_cmd = "make BUILD_STATIC=no PREFIX=/usr install",
    phase = "chroot",
    test_cmd = "make -j1 check",
    deps = [":glibc"],
)

# 8. Zstd - Compression library
lfs_package(
    name = "zstd",
    srcs = ["@zstd_src//file"],
    build_cmd = "make prefix=/usr",
    configure_cmd = "true",
    install_cmd = """
        make prefix=/usr install
        rm -v /usr/lib/libzstd.a
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":glibc"],
)

# 9. File - File type detection
lfs_configure_make(
    name = "file",
    srcs = ["@file_src//file"],
    configure_flags = ["--prefix=/usr"],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":glibc"],
)

# 10. Readline - Line editing library
lfs_package(
    name = "readline",
    srcs = ["@readline_src//file"],
    build_cmd = 'make SHLIB_LIBS="-lncursesw"',
    configure_cmd = """
        sed -i '/MV.*old/d' Makefile.in
        sed -i '/{OLDSUFF}/c:' support/shlib-install
        sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
        sed -e '270a\\
     else\\
       chars_avail = 1;'      \\
    -e '288i\\   result = -1;' \\
    -i.orig input.c
        ./configure --prefix=/usr \\
            --disable-static \\
            --with-curses \\
            --docdir=/usr/share/doc/readline-8.3
    """,
    install_cmd = """
        make install
        install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
    """,
    phase = "chroot",
    deps = [":glibc"],
)

# 10b. Pcre2 - Perl-compatible regular expressions (new in LFS 13.0)
lfs_configure_make(
    name = "pcre2",
    srcs = ["@pcre2_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--docdir=/usr/share/doc/pcre2-10.47",
        "--enable-unicode",
        "--enable-jit",
        "--enable-pcre2-16",
        "--enable-pcre2-32",
        "--enable-pcre2grep-libz",
        "--enable-pcre2grep-libbz2",
        "--enable-pcre2test-libreadline",
        "--disable-static",
    ],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [
        ":bzip2",
        ":readline",
        ":zlib",
    ],
)

# 11. M4 - Macro processor
lfs_configure_make(
    name = "m4",
    srcs = ["@m4_src//file"],
    configure_flags = ["--prefix=/usr"],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":glibc"],
)

# 12. Bc - Arbitrary precision calculator
lfs_package(
    name = "bc",
    srcs = ["@bc_src//file"],
    build_cmd = "make",
    configure_cmd = "CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make test",
    deps = [
        ":glibc",
        ":readline",
    ],
)

# 13. Flex - Lexical analyzer generator
lfs_package(
    name = "flex",
    srcs = ["@flex_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --docdir=/usr/share/doc/flex-2.6.4 \\
            --disable-static
    """,
    install_cmd = """
        make install
        ln -sfv flex /usr/bin/lex
        ln -sfv flex.1 /usr/share/man/man1/lex.1
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [
        ":glibc",
        ":m4",
    ],
)

# 14. Tcl - Tool Command Language
lfs_package(
    name = "tcl",
    srcs = ["@tcl_src//file"],
    build_cmd = """
        cd unix
        make
        sed -e "s|$SRCDIR/unix|/usr/lib|" \\
            -e "s|$SRCDIR|/usr/include|" \\
            -i tclConfig.sh
        sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.12|/usr/lib/tdbc1.1.12|" \\
            -e "s|$SRCDIR/pkgs/tdbc1.1.12/generic|/usr/include|" \\
            -e "s|$SRCDIR/pkgs/tdbc1.1.12/library|/usr/lib/tcl8.6|" \\
            -e "s|$SRCDIR/pkgs/tdbc1.1.12|/usr/include|" \\
            -i pkgs/tdbc1.1.12/tdbcConfig.sh
        sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.4|/usr/lib/itcl4.3.4|" \\
            -e "s|$SRCDIR/pkgs/itcl4.3.4/generic|/usr/include|" \\
            -e "s|$SRCDIR/pkgs/itcl4.3.4|/usr/include|" \\
            -i pkgs/itcl4.3.4/itclConfig.sh
        unset SRCDIR
    """,
    configure_cmd = """
        SRCDIR=$(pwd)
        cd unix
        ./configure --prefix=/usr \\
            --mandir=/usr/share/man \\
            --disable-rpath
    """,
    install_cmd = """
        cd unix
        make install
        chmod 644 /usr/lib/libtclstub8.6.a
        chmod -v u+w /usr/lib/libtcl8.6.so
        make install-private-headers
        ln -sfv tclsh8.6 /usr/bin/tclsh
        mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
    """,
    phase = "chroot",
    test_cmd = "cd unix && LC_ALL=C.UTF-8 make test",
    deps = [":glibc"],
)

# 15. Expect - Programmed dialogue tool
lfs_package(
    name = "expect",
    srcs = ["@expect_src//file"],
    build_cmd = "make",
    configure_cmd = """
        python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
        # expect bundles a 2003 tclconfig/config.guess that predates aarch64
        # ("cannot guess build type"); state --build explicitly.
        ./configure --prefix=/usr \\
            --build=$(uname -m)-unknown-linux-gnu \\
            --with-tcl=/usr/lib \\
            --enable-shared \\
            --disable-rpath \\
            --mandir=/usr/share/man \\
            --with-tclinclude=/usr/include
    """,
    install_cmd = """
        make install
        ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
    """,
    patches = ["@expect_gcc15_patch//file"],
    phase = "chroot",
    test_cmd = "make test",
    deps = [":tcl"],
)

# 16. DejaGNU - Testing framework
lfs_package(
    name = "dejagnu",
    srcs = ["@dejagnu_src//file"],
    build_cmd = "true",
    configure_cmd = """
        mkdir -v build
        cd build
        ../configure --prefix=/usr
        makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
        makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi
    """,
    install_cmd = """
        cd build
        make install
        install -v -dm755 /usr/share/doc/dejagnu-1.6.3
        install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
    """,
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":expect"],
)

# 17. Pkgconf - Package config tool
lfs_package(
    name = "pkgconf",
    srcs = ["@pkgconf_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/pkgconf-2.5.1
    """,
    install_cmd = """
        make install
        ln -sfv pkgconf /usr/bin/pkg-config
        ln -sfv pkgconf.1 /usr/share/man/man1/pkg-config.1
    """,
    phase = "chroot",
    deps = [":glibc"],
)

###############################################################################
# PHASE 3: Toolchain & Security (16 packages)
###############################################################################

# 18. Binutils - Binary tools (CRITICAL - requires tests)
# Expected test failures: one gprofng test (gold linker removed in binutils 2.46)
lfs_package(
    name = "binutils",
    srcs = ["@binutils_src//file"],
    build_cmd = "cd build && make tooldir=/usr",
    configure_cmd = """
        mkdir -v build
        cd build
        ../configure --prefix=/usr \\
            --sysconfdir=/etc \\
            --enable-ld=default \\
            --enable-plugins \\
            --enable-shared \\
            --disable-werror \\
            --enable-64-bit-bfd \\
            --enable-new-dtags \\
            --with-system-zlib \\
            --enable-default-hash-style=gnu
    """,
    install_cmd = """
        cd build
        make tooldir=/usr install
        rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a /usr/share/doc/gprofng/
    """,
    phase = "chroot",
    test_cmd = """
        cd build
        make -k check
        grep '^FAIL:' $(find -name '*.log') || true
    """,
    deps = [
        ":dejagnu",
        ":glibc",
        ":zlib",
    ],
)

# 19. GMP - Arbitrary precision math library
lfs_package(
    name = "gmp",
    srcs = ["@gmp_src//file"],
    build_cmd = """
        make
        make html
    """,
    configure_cmd = """
        sed -i '/long long t1;/,+1s/()/(...)/' configure
        ./configure --prefix=/usr \\
            --enable-cxx \\
            --disable-static \\
            --docdir=/usr/share/doc/gmp-6.3.0
    """,
    install_cmd = """
        make install
        make install-html
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":glibc"],
)

# 20. MPFR - Multiple precision floating-point library
lfs_package(
    name = "mpfr",
    srcs = ["@mpfr_src//file"],
    build_cmd = """
        make
        make html
    """,
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --enable-thread-safe \\
            --docdir=/usr/share/doc/mpfr-4.2.2
    """,
    install_cmd = """
        make install
        make install-html
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gmp"],
)

# 21. MPC - Complex numbers library
lfs_package(
    name = "mpc",
    srcs = ["@mpc_src//file"],
    build_cmd = """
        make
        make html
    """,
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/mpc-1.3.1
    """,
    install_cmd = """
        make install
        make install-html
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":mpfr"],
)

# 22. Attr - Extended attributes
lfs_configure_make(
    name = "attr",
    srcs = ["@attr_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--disable-static",
        "--sysconfdir=/etc",
        "--docdir=/usr/share/doc/attr-2.5.2",
    ],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":glibc"],
)

# 23. Acl - Access control lists
lfs_configure_make(
    name = "acl",
    srcs = ["@acl_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--disable-static",
        "--docdir=/usr/share/doc/acl-2.3.2",
    ],
    phase = "chroot",
    test_cmd = "cd build && make check",
    deps = [":attr"],
)

# 24. Libcap - POSIX capabilities
# NOTE: RAISE_SETFCAP=no because the rootless podman container lacks CAP_SETFCAP,
# so the book's install-time setcap step (and its "make test") would fail here.
lfs_package(
    name = "libcap",
    srcs = ["@libcap_src//file"],
    build_cmd = "make prefix=/usr lib=lib",
    configure_cmd = "sed -i '/install -m.*STA/d' libcap/Makefile",
    install_cmd = "make prefix=/usr lib=lib RAISE_SETFCAP=no install",
    phase = "chroot",
    deps = [":glibc"],
)

# 25. Libxcrypt - Password hashing library
lfs_configure_make(
    name = "libxcrypt",
    srcs = ["@libxcrypt_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--enable-hashes=strong,glibc",
        "--enable-obsolete-api=no",
        "--disable-static",
        "--disable-failure-tokens",
    ],
    phase = "chroot",
    pre_configure_cmds = ["sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c"],
    test_cmd = "cd build && make check",
    deps = [":glibc"],
)

# 26. Shadow - Password utilities (provides tester user utilities)
lfs_package(
    name = "shadow",
    srcs = ["@shadow_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed -i 's/groups$(EXEEXT) //' src/Makefile.in
        find man -name Makefile.in -exec sed -i 's/groups\\.1 / /' {} \\;
        find man -name Makefile.in -exec sed -i 's/getspnam\\.3 / /' {} \\;
        find man -name Makefile.in -exec sed -i 's/passwd\\.5 / /' {} \\;

        sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \\
            -e 's:/var/spool/mail:/var/mail:' \\
            -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \\
            -i etc/login.defs

        touch /usr/bin/passwd
        ./configure --sysconfdir=/etc \\
            --disable-static \\
            --with-{b,yes}crypt \\
            --without-libbsd \\
            --disable-logind \\
            --with-group-name-max-length=32
    """,
    install_cmd = """
        make exec_prefix=/usr install
        make -C man install-man

        # Post-install configuration.
        # shadow's pwconv/grpconv/useradd write /etc via commonio, which creates
        # a mode-000 temp file then reopens it O_WRONLY. On this host the sysroot
        # is virtiofs-backed, and virtiofs enforces the permission check a local
        # fs skips for the creator, so that open() fails EACCES. Reproduce the
        # exact pwconv/grpconv output with plain writes (mode 0600 works fine on
        # virtiofs). Format verified against real pwconv/grpconv on ext4.
        _lstchg=$(( $(date -u +%s) / 86400 ))
        awk -F: -v d="$_lstchg" '{print $1":x:"d":0:99999:7:::"}' /etc/passwd > /etc/shadow
        awk -F: '{print $1":x::"$4}' /etc/group > /etc/gshadow
        chmod 0600 /etc/shadow /etc/gshadow

        mkdir -p /etc/default
        cat > /etc/default/useradd <<'EOF'
GROUP=999
HOME=/home
INACTIVE=-1
EXPIRE=
SHELL=/bin/bash
SKEL=/etc/skel
CREATE_MAIL_SPOOL=yes
EOF
    """,
    phase = "chroot",
    deps = [
        ":acl",
        ":libxcrypt",
    ],
)

# 27. GCC - GNU Compiler Collection (CRITICAL - requires tests)
# Expected test failures: some analyzer tests, AVX-dependent vect tests
# Requires tester user (depends on shadow)
lfs_package(
    name = "gcc",
    srcs = ["@gcc_src//file"],
    # NOTE: GCC is memory-hungry (each cc1/cc1plus can use 1-2GB RAM).
    # -j8 is sized for the 8-vCPU / 14GB podman machine config.
    build_cmd = "cd build && make -j8",
    configure_cmd = """
        sed -i 's/char [*]q/const &/' libgomp/affinity-fmt.c

        # Both arches default their lp64 multilib OS dir to lib64; point it at
        # lib so runtime libs land in /usr/lib (ld.so never searches lib64 here).
        case $(uname -m) in
          x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
          ;;
          aarch64)
            sed -e '/lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
          ;;
        esac

        mkdir -v build
        cd build
        ../configure --prefix=/usr \\
            LD=ld \\
            --enable-languages=c,c++ \\
            --enable-default-pie \\
            --enable-default-ssp \\
            --enable-host-pie \\
            --disable-multilib \\
            --disable-bootstrap \\
            --disable-fixincludes \\
            --with-system-zlib
    """,
    install_cmd = """
        cd build
        make install
        chown -v -R root:root /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}
        ln -sfvr /usr/bin/cpp /usr/lib
        ln -sfv gcc.1 /usr/share/man/man1/cc.1
        ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so /usr/lib/bfd-plugins/

        # Verify installation
        echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
        readelf -l a.out | grep ': /lib'

        grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
        grep -B4 '^ /usr/include' dummy.log
        grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\\n|g'
        grep "/lib.*/libc.so.6 " dummy.log
        grep found dummy.log

        rm -v a.out dummy.log

        mkdir -pv /usr/share/gdb/auto-load/usr/lib
        mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
    """,
    phase = "chroot",
    test_cmd = """
        cd build
        ulimit -s -H unlimited
        sed -e '/cpython/d' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp

        chown -R tester .
        su tester -c "PATH=$PATH make -k check"
        ../contrib/test_summary
    """,
    deps = [
        ":binutils",
        ":dejagnu",
        ":gmp",
        ":mpc",
        ":mpfr",
        ":shadow",
        ":zlib",
    ],
)

# 28. Ncurses - Terminal handling library
lfs_package(
    name = "ncurses",
    srcs = ["@ncurses_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --mandir=/usr/share/man \\
            --with-shared \\
            --without-debug \\
            --without-normal \\
            --with-cxx-shared \\
            --enable-pc-files \\
            --with-pkg-config-libdir=/usr/lib/pkgconfig
    """,
    install_cmd = """
        make DESTDIR=$PWD/dest install
        sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
        cp --remove-destination -av dest/* /

        for lib in ncurses form panel menu ; do
            ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
            ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
        done

        ln -sfv libncursesw.so /usr/lib/libcurses.so

        cp -v -R doc -T /usr/share/doc/ncurses-6.6
    """,
    phase = "chroot",
    deps = [
        ":gcc",
        ":glibc",
    ],
)

# 29. Sed - Stream editor
lfs_package(
    name = "sed",
    srcs = ["@sed_src//file"],
    build_cmd = """
        make
        make html
    """,
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = """
        make install
        install -d -m755 /usr/share/doc/sed-4.9
        install -m644 doc/sed.html /usr/share/doc/sed-4.9
    """,
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        su tester -c "PATH=$PATH make check"
    """,
    deps = [":gcc"],
)

# 30. Psmisc - Process utilities
# In-tree build (book-faithful): psmisc's install-man1 references the shipped
# translated man pages as ../../man-po/*, which dangles in out-of-tree builds.
lfs_package(
    name = "psmisc",
    srcs = ["@psmisc_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":ncurses"],
)

# 31. Gettext - Internationalization utilities
lfs_package(
    name = "gettext",
    srcs = ["@gettext_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/gettext-1.0
    """,
    install_cmd = """
        make install
        chmod -v 0755 /usr/lib/preloadable_libintl.so
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":ncurses"],
)

# 32. Bison - Parser generator
lfs_configure_make(
    name = "bison",
    srcs = ["@bison_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--docdir=/usr/share/doc/bison-3.8.2",
    ],
    phase = "chroot",
    # lfs_configure_make builds out-of-tree; the Makefile lives in build/.
    test_cmd = "cd build && make check",
    deps = [
        ":gcc",
        ":glibc",
    ],
)

# 33. Grep - Pattern matching utility
lfs_package(
    name = "grep",
    srcs = ["@grep_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed -i "s/echo/#echo/" src/egrep.sh
        ./configure --prefix=/usr
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [
        ":gcc",
        ":glibc",
    ],
)

###############################################################################
# Phase 4: Build System & Python (25 packages)
###############################################################################

# 34. Bash - Shell
lfs_package(
    name = "bash",
    srcs = ["@bash_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --without-bash-malloc \\
            --with-installed-readline \\
            --docdir=/usr/share/doc/bash-5.3
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
    """,
    deps = [
        ":ncurses",
        ":readline",
    ],
)

# 35. Libtool - Library support script
lfs_package(
    name = "libtool",
    srcs = ["@libtool_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = """
        make install
        rm -fv /usr/lib/libltdl.a
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 36. GDBM - Database library
lfs_package(
    name = "gdbm",
    srcs = ["@gdbm_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --enable-libgdbm-compat
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":readline"],
)

# 37. Gperf - Perfect hash function generator
lfs_package(
    name = "gperf",
    srcs = ["@gperf_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 38. Expat - XML parser library
lfs_package(
    name = "expat",
    srcs = ["@expat_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/expat-2.7.4
    """,
    install_cmd = """
        make install
        install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.4
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 39. Inetutils - Basic networking programs
lfs_package(
    name = "inetutils",
    srcs = ["@inetutils_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
        ./configure --prefix=/usr \\
            --bindir=/usr/bin \\
            --localstatedir=/var \\
            --disable-logger \\
            --disable-whois \\
            --disable-rcp \\
            --disable-rexec \\
            --disable-rlogin \\
            --disable-rsh \\
            --disable-servers
    """,
    install_cmd = """
        make install
        mv -v /usr/{,s}bin/ifconfig
    """,
    phase = "chroot",
    deps = [":ncurses"],
)

# 40. Less - Text file viewer
lfs_package(
    name = "less",
    srcs = ["@less_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr --sysconfdir=/etc",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":ncurses"],
)

# 41. Perl - Programming language
lfs_package(
    name = "perl",
    srcs = ["@perl_src//file"],
    build_cmd = "make",
    configure_cmd = """
        export BUILD_ZLIB=False
        export BUILD_BZIP2=0
        sh Configure -des \\
            -D prefix=/usr \\
            -D vendorprefix=/usr \\
            -D privlib=/usr/lib/perl5/5.42/core_perl \\
            -D archlib=/usr/lib/perl5/5.42/core_perl \\
            -D sitelib=/usr/lib/perl5/5.42/site_perl \\
            -D sitearch=/usr/lib/perl5/5.42/site_perl \\
            -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \\
            -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \\
            -D man1dir=/usr/share/man/man1 \\
            -D man3dir=/usr/share/man/man3 \\
            -D pager="/usr/bin/less -isR" \\
            -D useshrplib \\
            -D usethreads
    """,
    install_cmd = """
        make install
        unset BUILD_ZLIB BUILD_BZIP2
    """,
    phase = "chroot",
    test_cmd = "TEST_JOBS=$(nproc) make test_harness",
    deps = [":gdbm"],
)

# 42. XML::Parser - Perl XML parser module
lfs_package(
    name = "xml_parser",
    srcs = ["@xml_parser_src//file"],
    build_cmd = "make",
    configure_cmd = "perl Makefile.PL",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make test",
    deps = [
        ":expat",
        ":perl",
    ],
)

# 43. Intltool - Internationalization tool
lfs_package(
    name = "intltool",
    srcs = ["@intltool_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed -i 's:\\\\\\\\\\\\${:\\\\\\\\\\\\$\\\\\\\\\\\\{:' intltool-update.in
        ./configure --prefix=/usr
    """,
    install_cmd = """
        make install
        install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
    """,
    phase = "chroot",
    deps = [":xml_parser"],
)

# 44. Autoconf - Build configuration tool
lfs_package(
    name = "autoconf",
    srcs = ["@autoconf_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [
        ":m4",
        ":perl",
    ],
)

# 45. Automake - Makefile generator
lfs_package(
    name = "automake",
    srcs = ["@automake_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make -j$(($(nproc)>4?$(nproc):4)) check",
    deps = [":autoconf"],
)

# 46. OpenSSL - Cryptography library
lfs_package(
    name = "openssl",
    srcs = ["@openssl_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./config --prefix=/usr \\
            --openssldir=/etc/ssl \\
            --libdir=lib \\
            shared \\
            zlib-dynamic
    """,
    install_cmd = """
        sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
        make MANSUFFIX=ssl install
        mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.6.1
        cp -vfr doc/* /usr/share/doc/openssl-3.6.1
    """,
    phase = "chroot",
    test_cmd = "HARNESS_JOBS=$(nproc) make test",
    deps = [":zlib"],
)

# 47. Kmod - Kernel module tools
# NOTE: kmod-34.2 dropped autotools; built with meson/ninja. Now builds after Meson.
lfs_package(
    name = "kmod",
    srcs = ["@kmod_src//file"],
    build_cmd = """
        cd build
        ninja
    """,
    configure_cmd = """
        mkdir -p build
        cd build
        meson setup --prefix=/usr .. \\
            --sbindir=/usr/sbin \\
            --buildtype=release \\
            -D manpages=false
    """,
    install_cmd = """
        cd build
        ninja install
    """,
    phase = "chroot",
    deps = [
        ":meson",
        ":ninja",
        ":openssl",
        ":pkgconf",
        ":xz",
        ":zstd",
    ],
)

# 48. Libelf - ELF library from elfutils
lfs_package(
    name = "libelf",
    srcs = ["@libelf_src//file"],
    build_cmd = """
        make -C lib
        make -C libelf
    """,
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-debuginfod \\
            --enable-libdebuginfod=dummy
    """,
    install_cmd = """
        make -C libelf install
        install -vm644 config/libelf.pc /usr/lib/pkgconfig
        rm /usr/lib/libelf.a
    """,
    phase = "chroot",
    deps = [
        # .tar.bz2 source: the ch6 temp tools have no bzip2, so extraction in
        # the chroot needs ch8's bzip2 installed first.
        ":bzip2",
        ":zlib",
    ],
)

# 49. Libffi - Foreign function interface library
lfs_package(
    name = "libffi",
    srcs = ["@libffi_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --with-gcc-arch=native
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 49b. Sqlite - SQL database engine (new in LFS 13.0, needed for Python sqlite3 module)
lfs_package(
    name = "sqlite",
    srcs = ["@sqlite_src//file"],
    build_cmd = 'make LDFLAGS.rpath=""',
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --enable-fts{4,5} \\
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \\
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 \\
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1 \\
                      -D SQLITE_SECURE_DELETE=1"
    """,
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":gcc",
        ":readline",
    ],
)

# 50. Python - Programming language
lfs_package(
    name = "python",
    srcs = ["@python_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --enable-shared \\
            --with-system-expat \\
            --enable-optimizations \\
            --without-static-libpython
    """,
    install_cmd = """
        make install
        cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
    """,
    phase = "chroot",
    test_cmd = """
        make test TESTOPTS="--timeout 120"
    """,
    deps = [
        ":expat",
        ":libffi",
        ":openssl",
        ":sqlite",
    ],
)

# 51. Flit-Core - Python build backend
lfs_package(
    name = "flit_core",
    srcs = ["@flit_core_src//file"],
    build_cmd = """
        pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    """,
    install_cmd = """
        pip3 install --no-index --find-links dist flit_core
    """,
    phase = "chroot",
    deps = [":python"],
)

# 51b. Packaging - Python core packaging utilities (new in LFS 13.0, required by Wheel)
lfs_package(
    name = "packaging",
    srcs = ["@packaging_src//file"],
    build_cmd = """
        pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    """,
    install_cmd = """
        pip3 install --no-index --find-links dist packaging
    """,
    phase = "chroot",
    deps = [
        ":flit_core",
        ":python",
    ],
)

# 52. Wheel - Python wheel packaging standard
lfs_package(
    name = "wheel",
    srcs = ["@wheel_src//file"],
    build_cmd = """
        pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    """,
    install_cmd = """
        pip3 install --no-index --find-links=dist wheel
    """,
    phase = "chroot",
    deps = [
        ":flit_core",
        ":packaging",
    ],
)

# 53. Setuptools - Python package installer
lfs_package(
    name = "setuptools",
    srcs = ["@setuptools_src//file"],
    build_cmd = """
        pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    """,
    install_cmd = """
        pip3 install --no-index --find-links dist setuptools
    """,
    phase = "chroot",
    deps = [":python"],
)

# 54. Ninja - Build system
lfs_package(
    name = "ninja",
    srcs = ["@ninja_src//file"],
    configure_cmd = """
        sed -i '/int Guess/a \\
  int   j = 0;\\
  char* jobs = getenv( "NINJAJOBS" );\\
  if ( jobs != NULL ) j = atoi( jobs );\\
  if ( j > 0 ) return j;\\
' src/ninja.cc
        python3 configure.py --bootstrap --verbose
    """,
    install_cmd = """
        install -vm755 ninja /usr/bin/
        install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
        install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
    """,
    phase = "chroot",
    deps = [":python"],
)

# 55. Meson - Build system
lfs_package(
    name = "meson",
    srcs = ["@meson_src//file"],
    build_cmd = """
        pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    """,
    configure_cmd = "true",
    install_cmd = """
        pip3 install --no-index --find-links dist meson
        install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
        install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
    """,
    phase = "chroot",
    deps = [
        ":ninja",
        ":python",
        ":setuptools",
    ],
)

# 56. Coreutils - Core utilities
# Expected test failures: preserve-mode.sh, acl.sh (chroot only)
# Requires tester user (depends on shadow)
lfs_package(
    name = "coreutils",
    srcs = ["@coreutils_src//file"],
    build_cmd = "make",
    configure_cmd = """
        autoreconf -fv
        automake -af
        FORCE_UNSAFE_CONFIGURE=1 ./configure \\
            --prefix=/usr
    """,
    install_cmd = """
        make install
        mv -v /usr/bin/chroot /usr/sbin
        mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
        sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
    """,
    patches = ["@coreutils_i18n_patch//file"],
    phase = "chroot",
    test_cmd = """
        make NON_ROOT_USERNAME=tester check-root
        # groupadd/groupdel write /etc via shadow's commonio, which fails
        # EACCES on the virtiofs sysroot (see the shadow recipe). Reproduce
        # their output with plain writes instead.
        echo "dummy:x:102:tester" >> /etc/group
        echo "dummy:x::tester" >> /etc/gshadow
        chown -R tester .
        su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" < /dev/null
        sed -i '/^dummy:/d' /etc/group /etc/gshadow
    """,
    deps = [
        ":acl",
        # The i18n patch requires autoreconf; without this dep bazel may
        # schedule coreutils before automake has installed aclocal.
        ":automake",
        ":gmp",
        ":libcap",
        ":shadow",
    ],
)

################################################################################
# Phase 5: System Services (20 packages)
################################################################################

# 58. diffutils - File comparison utilities
lfs_package(
    name = "diffutils",
    srcs = ["@diffutils_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 59. gawk - Pattern scanning and processing language
lfs_package(
    name = "gawk",
    srcs = ["@gawk_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed -i 's/extras//' Makefile.in
        ./configure --prefix=/usr
    """,
    install_cmd = """
        rm -f /usr/bin/gawk-*
        make install
        ln -sfv gawk.1 /usr/share/man/man1/awk.1
        mkdir -pv /usr/share/doc/gawk-5.3.2
        cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.3.2 2>/dev/null || true
    """,
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        su tester -c "PATH=$PATH make check"
    """,
    deps = [
        ":gmp",
        ":mpfr",
    ],
)

# 60. findutils - File finding utilities
lfs_package(
    name = "findutils",
    srcs = ["@findutils_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr --localstatedir=/var/lib/locate",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        su tester -c "PATH=$PATH make check"
    """,
    deps = [":gcc"],
)

# 61. groff - Document formatting system
lfs_package(
    name = "groff",
    srcs = ["@groff_src//file"],
    build_cmd = "make",
    configure_cmd = "PAGE=letter ./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc", ":perl"],
)

# 62. grub - GRand Unified Bootloader
lfs_package(
    name = "grub",
    srcs = ["@grub_src//file"],
    build_cmd = "make",
    configure_cmd = """
        unset {C,CPP,CXX,LD}FLAGS
        sed 's/--image-base/--nonexist-linker-option/' -i configure
        ./configure --prefix=/usr \\
            --sysconfdir=/etc \\
            --disable-efiemu \\
            --disable-werror
    """,
    install_cmd = """
        make install
        # Book moves the completion file, but grub's efi-default configure on
        # aarch64 may not install it under /etc at all; move only if present.
        if [ -f /etc/bash_completion.d/grub ]; then
            mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
        fi
    """,
    phase = "chroot",
    deps = [":bison", ":flex", ":gcc", ":python"],
)

# 62b. grub_efi - GRUB rebuilt with the UEFI platform (BLFS)
# Second GRUB build from the SAME tarball, EFI platform. BIOS :grub is built
# first (full install of host utilities); here we install ONLY the platform
# modules via `make -C grub-core install`, which lands the EFI modules used by
# `grub-mkstandalone` in chapter_10.
lfs_package(
    name = "grub_efi",
    srcs = ["@grub_src//file"],
    build_cmd = "make",
    configure_cmd = """
        unset {C,CPP,CXX,LD}FLAGS
        sed 's/--image-base/--nonexist-linker-option/' -i configure
        echo 'depends bli part_gpt' > grub-core/extra_deps.lst
        case $(uname -m) in
          x86_64) grub_target=x86_64 ;;
          aarch64) grub_target=aarch64 ;;
          *) echo "unsupported EFI GRUB target: $(uname -m)" >&2; exit 1 ;;
        esac
        ./configure --prefix=/usr \\
            --sysconfdir=/etc \\
            --disable-efiemu \\
            --with-platform=efi \\
            --target=$grub_target \\
            --disable-werror
    """,
    install_cmd = "make -C grub-core install",
    phase = "chroot",
    deps = [
        ":bison",
        ":flex",
        ":grub",
        ":python",
    ],
)

# 63. gzip - Compression utilities
lfs_package(
    name = "gzip",
    srcs = ["@gzip_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 64. iproute2 - IP routing utilities
lfs_package(
    name = "iproute2",
    srcs = ["@iproute2_src//file"],
    build_cmd = "make NETNS_RUN_DIR=/run/netns",
    configure_cmd = """
        sed -i /ARPD/d Makefile
        rm -fv man/man8/arpd.8
    """,
    install_cmd = """
        make SBINDIR=/usr/sbin install
        install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.18.0
    """,
    phase = "chroot",
    deps = [":libelf"],
)

# 65. kbd - Keyboard utilities
lfs_package(
    name = "kbd",
    srcs = [
        "@kbd_backspace_patch//file",
        "@kbd_src//file",
    ],
    build_cmd = "make",
    configure_cmd = """
        patch -Np1 -i ../kbd-*-backspace-1.patch
        sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
        sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
        ./configure --prefix=/usr --disable-vlock
    """,
    install_cmd = """
        make install
        cp -R -v docs/doc -T /usr/share/doc/kbd-* 2>/dev/null || true
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 66. libpipeline - Pipeline manipulation library
lfs_package(
    name = "libpipeline",
    srcs = ["@libpipeline_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    deps = [":gcc"],
)

# 67. make - Build automation tool
lfs_package(
    name = "make",
    srcs = ["@make_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        su tester -c "PATH=$PATH make check"
    """,
    deps = [":gcc"],
)

# 68. patch - Apply diff files to originals
lfs_package(
    name = "patch",
    srcs = ["@patch_src//file"],
    build_cmd = "make",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [":gcc"],
)

# 68b. cpio - Archiver (required by mkinitramfs to build the initramfs)
lfs_package(
    name = "cpio",
    srcs = ["@cpio_src//file"],
    build_cmd = "make",
    configure_cmd = """
        # cpio-2.15 declares K&R-style xstat(); gcc-15's C23 default reads ()
        # as zero-arg and errors ("too many arguments to function 'xstat'").
        # Build as gnu17, per BLFS guidance for gcc >= 14.
        ./configure --prefix=/usr \\
            --enable-mt \\
            --with-rmt=/usr/libexec/rmt \\
            CFLAGS="-O2 -std=gnu17"
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [
        # .tar.bz2 source: chroot extraction needs ch8's bzip2 (see libelf).
        ":bzip2",
        ":gcc",
    ],
)

# 69. tar - Archiving utility
lfs_package(
    name = "tar",
    srcs = ["@tar_src//file"],
    build_cmd = "make",
    configure_cmd = """
        FORCE_UNSAFE_CONFIGURE=1 \\
        ./configure --prefix=/usr
    """,
    install_cmd = """
        make install
        make -C doc install-html docdir=/usr/share/doc/tar-1.35
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":acl"],
)

# 70. texinfo - Documentation system
lfs_package(
    name = "texinfo",
    srcs = ["@texinfo_src//file"],
    build_cmd = "make",
    configure_cmd = """
        sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
        ./configure --prefix=/usr
    """,
    install_cmd = """
        make install
        make TEXMF=/usr/share/texmf install-tex
    """,
    phase = "chroot",
    test_cmd = "make check",
    deps = [":perl"],
)

# 71. vim - Text editor
lfs_package(
    name = "vim",
    srcs = ["@vim_src//file"],
    build_cmd = "make",
    configure_cmd = """
        echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
        ./configure --prefix=/usr
    """,
    install_cmd = """
        make install
        ln -sfv vim /usr/bin/vi
        for L in /usr/share/man/{,*/}man1/vim.1; do
            ln -sfv vim.1 $(dirname $L)/vi.1
        done
        ln -sfv ../vim/vim92/doc /usr/share/doc/vim-9.2.0078
    """,
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
        su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
    """,
    deps = [":ncurses"],
)

# 72. markupsafe - Python module with C extension
lfs_package(
    name = "markupsafe",
    srcs = ["@markupsafe_src//file"],
    build_cmd = "pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD",
    configure_cmd = "true",
    install_cmd = "pip3 install --no-index --find-links dist Markupsafe",
    phase = "chroot",
    deps = [
        ":python",
        ":setuptools",
    ],
)

# 73. jinja2 - Python templating module
lfs_package(
    name = "jinja2",
    srcs = ["@jinja2_src//file"],
    build_cmd = "pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD",
    configure_cmd = "true",
    install_cmd = "pip3 install --no-index --find-links dist Jinja2",
    phase = "chroot",
    deps = [
        ":flit_core",
        ":markupsafe",
        ":python",
    ],
)

# 74. systemd - System and service manager
# NOTE: systemd_src must be first so SRC_DIR is set correctly
lfs_package(
    name = "systemd",
    srcs = [
        "@systemd_src//file",
        "@systemd_man_pages//file",
    ],
    build_cmd = """
        cd build
        ninja
    """,
    configure_cmd = """
        sed -i -e 's/GROUP="render"/GROUP="video"/' \\
               -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in

        mkdir -p build
        cd build

        meson setup .. \\
              --prefix=/usr \\
              --buildtype=release \\
              -D default-dnssec=no \\
              -D firstboot=false \\
              -D install-tests=false \\
              -D ldconfig=false \\
              -D sysusers=false \\
              -D rpmmacrosdir=no \\
              -D homed=disabled \\
              -D man=disabled \\
              -D mode=release \\
              -D pamconfdir=no \\
              -D dev-kvm-mode=0660 \\
              -D nobody-group=nogroup \\
              -D sysupdate=disabled \\
              -D ukify=disabled \\
              -D docdir=/usr/share/doc/systemd-259.1
    """,
    install_cmd = """
        cd build
        ninja install
        # src_handling extracts every srcs tarball into WORKDIR; the raw
        # .tar.xz never lands there. Resolve the staged tarball path from
        # $LFS_PKG_SRCS_FILE (absolute /execroot paths, valid in the chroot).
        MAN_SRC="$(grep 'systemd-man-pages' "$LFS_PKG_SRCS_FILE")"
        tar -xf "$MAN_SRC" \\
            --no-same-owner --strip-components=1 \\
            -C /usr/share/man
        systemd-machine-id-setup
        systemctl preset-all
    """,
    phase = "chroot",
    test_cmd = """
        echo 'NAME="Linux From Scratch"' > /etc/os-release
        cd build
        unshare -m ninja test
    """,
    deps = [
        ":gperf",
        ":jinja2",
        ":kmod",
        ":libcap",
        ":libelf",
        ":meson",
        ":ninja",
        ":openssl",
    ],
)

# 75. dbus - Message bus system
lfs_package(
    name = "dbus",
    srcs = ["@dbus_src//file"],
    build_cmd = """
        cd build
        ninja
    """,
    configure_cmd = """
        mkdir build
        cd build
        meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
    """,
    install_cmd = """
        cd build
        ninja install
        ln -sfv /etc/machine-id /var/lib/dbus
        # meson installs the launch helper execute-only (mode 110); on the
        # virtiofs sysroot even container-root then cannot read it (virtiofs
        # ignores CAP_DAC_OVERRIDE), which breaks the ch11 image staging tar.
        # Restore the book's 4750.
        chmod 4750 /usr/libexec/dbus-daemon-launch-helper
    """,
    phase = "chroot",
    test_cmd = """
        cd build
        ninja test
    """,
    deps = [
        ":meson",
        ":ninja",
        ":systemd",
    ],
)

# 76. procps - Process monitoring utilities (procps-ng)
lfs_package(
    name = "procps",
    srcs = ["@procps_ng_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --docdir=/usr/share/doc/procps-ng-4.0.6 \\
            --disable-static \\
            --disable-kill \\
            --enable-watch8bit \\
            --with-systemd
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = """
        chown -R tester .
        su tester -c "PATH=$PATH make check"
    """,
    deps = [
        ":ncurses",
        ":systemd",
    ],
)

# 77. man_db - Manual pager utilities
lfs_package(
    name = "man_db",
    srcs = ["@man_db_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --docdir=/usr/share/doc/man-db-2.13.1 \\
            --sysconfdir=/etc \\
            --disable-setuid \\
            --enable-cache-owner=bin \\
            --with-browser=/usr/bin/lynx \\
            --with-vgrind=/usr/bin/vgrind \\
            --with-grap=/usr/bin/grap
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = "make check",
    deps = [
        ":gdbm",
        # man_db's build formats its own manual with groff's soelim/tbl;
        # without this dep bazel may schedule man_db before groff installs.
        ":groff",
        ":libpipeline",
        # Book order: man-db expects systemd (tmpfiles) already in place.
        ":systemd",
    ],
)

################################################################################
# Phase 6: Final Packages (2 packages)
################################################################################

# 78. util_linux - Miscellaneous system utilities
lfs_package(
    name = "util_linux",
    srcs = ["@util_linux_src//file"],
    build_cmd = "make",
    configure_cmd = """
        ./configure --bindir=/usr/bin \\
            --libdir=/usr/lib \\
            --runstatedir=/run \\
            --sbindir=/usr/sbin \\
            --disable-chfn-chsh \\
            --disable-login \\
            --disable-nologin \\
            --disable-su \\
            --disable-setpriv \\
            --disable-runuser \\
            --disable-pylibmount \\
            --disable-liblastlog2 \\
            --disable-static \\
            --without-python \\
            ADJTIME_PATH=/var/lib/hwclock/adjtime \\
            --docdir=/usr/share/doc/util-linux-2.41.3
    """,
    install_cmd = "make install",
    phase = "chroot",
    test_cmd = """
        touch /etc/fstab
        chown -R tester .
        su tester -c "make -k check"
    """,
    deps = [
        ":libcap",
        ":ncurses",
        ":systemd",
    ],
)

# 79. e2fsprogs - Ext2/3/4 filesystem utilities
lfs_package(
    name = "e2fsprogs",
    srcs = ["@e2fsprogs_src//file"],
    build_cmd = """
        cd build
        make
    """,
    configure_cmd = """
        mkdir -v build
        cd build
        ../configure --prefix=/usr \\
             --sysconfdir=/etc \\
             --enable-elf-shlibs \\
             --disable-libblkid \\
             --disable-libuuid \\
             --disable-uuidd \\
             --disable-fsck
    """,
    install_cmd = """
        cd build
        make install
        rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
        gunzip -v /usr/share/info/libext2fs.info.gz
        install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
        makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
        install -v -m644 doc/com_err.info /usr/share/info
        install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
    """,
    phase = "chroot",
    test_cmd = """
        cd build
        make check
    """,
    deps = [":util_linux"],
)

###############################################################################
# Smoke Test / Validation
###############################################################################

# Quick validation of core Chapter 8 toolchain inside chroot
# Pattern follows chapter_07/BUILD:chroot_smoke_versions
lfs_package(
    name = "ch8_smoke_versions",
    build_cmd = """
        echo "=== Chapter 8 Toolchain Validation ==="
        echo ""
        echo "GCC version:"
        gcc --version | head -1
        echo "G++ version:"
        g++ --version | head -1
        echo "Binutils (ld):"
        ld --version | head -1
        echo "Glibc (ldd):"
        ldd --version | head -1
        echo "Bash:"
        bash --version | head -1
        echo "Make:"
        make --version | head -1
        echo "Python:"
        python3 --version
        echo "Perl:"
        perl -V:version
        echo ""
        echo "=== Compiler Test ==="
        echo 'int main(){return 0;}' > /tmp/ch8_test.c
        gcc -o /tmp/ch8_test /tmp/ch8_test.c
        /tmp/ch8_test && echo "GCC compilation: OK"
        rm -f /tmp/ch8_test /tmp/ch8_test.c
        echo ""
        echo "=== Chapter 8 Smoke Test PASSED ==="
    """,
    configure_cmd = "true",
    install_cmd = "true",
    phase = "chroot",
    deps = [
        ":bash",
        ":gcc",
        ":make",
        ":perl",
        ":python",
    ],
)

###############################################################################
# Build All Target
###############################################################################

filegroup(
    name = "chapter_08",
    srcs = [
        # Phase 2: Core Foundation (18 packages)
        ":man_pages",
        ":iana_etc",
        ":glibc",
        ":zlib",
        ":bzip2",
        ":xz",
        ":lz4",
        ":zstd",
        ":file",
        ":readline",
        ":pcre2",
        ":m4",
        ":bc",
        ":flex",
        ":tcl",
        ":expect",
        ":dejagnu",
        ":pkgconf",
        # Phase 3: Toolchain & Security (16 packages)
        ":binutils",
        ":gmp",
        ":mpfr",
        ":mpc",
        ":attr",
        ":acl",
        ":libcap",
        ":libxcrypt",
        ":shadow",
        ":gcc",
        ":ncurses",
        ":sed",
        ":psmisc",
        ":gettext",
        ":bison",
        ":grep",
        # Phase 4: Build System & Python (25 packages)
        ":bash",
        ":libtool",
        ":gdbm",
        ":gperf",
        ":expat",
        ":inetutils",
        ":less",
        ":perl",
        ":xml_parser",
        ":intltool",
        ":autoconf",
        ":automake",
        ":openssl",
        ":kmod",
        ":libelf",
        ":libffi",
        ":sqlite",
        ":python",
        ":flit_core",
        ":packaging",
        ":wheel",
        ":setuptools",
        ":ninja",
        ":meson",
        ":coreutils",
        # Phase 5: System Services (20 packages)
        ":diffutils",
        ":gawk",
        ":findutils",
        ":groff",
        ":grub",
        ":grub_efi",
        ":gzip",
        ":iproute2",
        ":kbd",
        ":libpipeline",
        ":make",
        ":patch",
        ":cpio",
        ":tar",
        ":texinfo",
        ":vim",
        ":markupsafe",
        ":jinja2",
        ":systemd",
        ":dbus",
        ":procps",
        ":man_db",
        # Phase 6: Final Packages (2 packages)
        ":util_linux",
        ":e2fsprogs",
    ],
)
