"""
Chapter 10: Making the LFS System Bootable

This chapter involves:
1. Building the Linux Kernel (with initramfs + EFI/GPT support)
2. Generating an initramfs (mkinitramfs + LFS-built cpio)
3. Configuring the GRUB bootloader (BIOS grub.cfg + standalone UEFI GRUB)
"""

load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# Linux Kernel Configuration
# --------------------------------------------------------------------------- #

lfs_script(
    name = "kernel_config",
    script = """
        # Create /etc/modprobe.d/usb.conf for USB module load order
        install -v -m755 -d /etc/modprobe.d
        cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF

        # Ensure /boot exists
        mkdir -pv /boot
    """,
    deps = ["//packages/chapter_09"],  # Ensure chapter 9 is complete first
)

# --------------------------------------------------------------------------- #
# Linux Kernel
# --------------------------------------------------------------------------- #

lfs_package(
    name = "kernel",
    srcs = ["@linux_headers_src//file"],
    build_cmd = """
        make mrproper
        make defconfig

        # Enable required systemd options
        scripts/config --enable CONFIG_PSI
        scripts/config --disable CONFIG_PSI_DEFAULT_DISABLED
        scripts/config --disable CONFIG_IKHEADERS
        scripts/config --enable CONFIG_CGROUPS
        scripts/config --enable CONFIG_MEMCG
        scripts/config --enable CONFIG_CGROUP_SCHED
        scripts/config --disable CONFIG_RT_GROUP_SCHED
        scripts/config --enable CONFIG_RELOCATABLE
        scripts/config --enable CONFIG_RANDOMIZE_BASE
        scripts/config --enable CONFIG_STACKPROTECTOR
        scripts/config --enable CONFIG_STACKPROTECTOR_STRONG
        scripts/config --enable CONFIG_NET
        scripts/config --enable CONFIG_INET
        scripts/config --enable CONFIG_IPV6
        scripts/config --disable CONFIG_UEVENT_HELPER
        scripts/config --enable CONFIG_DEVTMPFS
        scripts/config --enable CONFIG_DEVTMPFS_MOUNT
        scripts/config --enable CONFIG_FW_LOADER
        scripts/config --disable CONFIG_FW_LOADER_USER_HELPER
        scripts/config --enable CONFIG_DMIID

        # Graphics / early boot console (13.0 kernel page)
        scripts/config --enable CONFIG_SYSFB_SIMPLEFB
        scripts/config --enable CONFIG_DRM
        scripts/config --enable CONFIG_DRM_PANIC
        scripts/config --set-str CONFIG_DRM_PANIC_SCREEN kmsg
        scripts/config --enable CONFIG_DRM_FBDEV_EMULATION
        scripts/config --enable CONFIG_DRM_SIMPLEDRM
        scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE

        # x86_64-only options
        case $(uname -m) in
          x86_64)
            scripts/config --enable CONFIG_X86_X2APIC
            scripts/config --enable CONFIG_IRQ_REMAP
          ;;
        esac
        scripts/config --enable CONFIG_PCI
        scripts/config --enable CONFIG_PCI_MSI
        scripts/config --enable CONFIG_IOMMU_SUPPORT

        scripts/config --enable CONFIG_INOTIFY_USER
        scripts/config --enable CONFIG_TMPFS
        scripts/config --enable CONFIG_TMPFS_POSIX_ACL

        # Disable warnings-as-errors to avoid build failures
        scripts/config --disable CONFIG_WERROR

        # Canonical kernel-release string (uname -r == modules dir == vmlinuz suffix)
        scripts/config --set-str CONFIG_LOCALVERSION "-lfs-13.0-systemd"
        scripts/config --disable CONFIG_LOCALVERSION_AUTO

        # initramfs support (mkinitramfs produces a gzip-compressed cpio)
        scripts/config --enable CONFIG_BLK_DEV_INITRD
        scripts/config --enable CONFIG_RD_GZIP

        # UEFI + GPT (EFI_PARTITION required to enumerate the GPT root partition)
        scripts/config --enable CONFIG_EFI
        scripts/config --enable CONFIG_EFI_STUB
        scripts/config --enable CONFIG_EFI_PARTITION
        scripts/config --enable CONFIG_EFIVAR_FS
        scripts/config --enable CONFIG_FB_EFI

        # Disk controllers for QEMU q35 (AHCI) and virtio
        scripts/config --enable CONFIG_ATA
        scripts/config --enable CONFIG_SATA_AHCI
        scripts/config --enable CONFIG_VIRTIO
        scripts/config --enable CONFIG_VIRTIO_PCI
        scripts/config --enable CONFIG_VIRTIO_BLK
        # Pin explicitly: only some defconfigs enable it, and chapter 9 sets
        # up systemd-networkd expecting a virtio NIC under QEMU.
        scripts/config --enable CONFIG_VIRTIO_NET

        # Root filesystem
        scripts/config --enable CONFIG_EXT4_FS

        # Resolve any dependency issues
        make olddefconfig

        # Build kernel and modules
        case $(uname -m) in
          x86_64) kernel_image=bzImage ;;
          aarch64) kernel_image=Image ;;
          *) echo "unsupported kernel image target: $(uname -m)" >&2; exit 1 ;;
        esac
        make -j$(nproc) "$kernel_image"
        make -j$(nproc) modules
    """,
    configure_cmd = "true",
    install_cmd = """
        make modules_install

        # Install kernel image (use -f to overwrite without prompting)
        case $(uname -m) in
          x86_64) kernel_image=arch/x86/boot/bzImage ;;
          aarch64) kernel_image=arch/arm64/boot/Image ;;
          *) echo "unsupported kernel image target: $(uname -m)" >&2; exit 1 ;;
        esac
        cp -fv "$kernel_image" /boot/vmlinuz-6.18.10-lfs-13.0-systemd

        # Install symbol map and config
        cp -fv System.map /boot/System.map-6.18.10-lfs-13.0-systemd
        cp -fv .config /boot/config-6.18.10-lfs-13.0-systemd

        # Install documentation
        install -d /usr/share/doc/linux-6.18.10-lfs-13.0-systemd
        cp -r Documentation/* /usr/share/doc/linux-6.18.10-lfs-13.0-systemd
    """,
    phase = "chroot",
    deps = [
        ":kernel_config",
        "//packages/chapter_08:bc",
        "//packages/chapter_08:bison",
        "//packages/chapter_08:flex",
        "//packages/chapter_08:kmod",
        "//packages/chapter_08:libelf",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:perl",
        "//packages/chapter_08:python",
        "//packages/chapter_08:toolchain",
    ],
)

# --------------------------------------------------------------------------- #
# GRUB Configuration
# --------------------------------------------------------------------------- #
#
# NOTE: the primary boot path is now UEFI self-boot. The standalone GRUB EFI
# binary /boot/EFI/BOOT/BOOT*.EFI (built by :efi_bootloader via
# grub-mkstandalone) carries its own embedded grub.cfg that resolves the root
# filesystem by LABEL=lfs-root and loads the kernel + initramfs; firmware runs it
# from the removable-media fallback path, so no efibootmgr/NVRAM entry is needed.
# The book's `grub-install /dev/sda` step (needs a loop device) is still skipped.
# This on-disk /boot/grub/grub.cfg is kept only as a reference / BIOS config; it
# now uses root=LABEL=lfs-root + the initramfs to match the UEFI menuentry. The
# raw whole-disk ext4 image booted via QEMU `-kernel` remains a documented
# fast-iteration fallback.

lfs_script(
    name = "grub_config",
    script = """
        mkdir -pv /boot/grub

        cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0)

menuentry "GNU/Linux, Linux 6.18.10-lfs-13.0-systemd" {
    linux   /boot/vmlinuz-6.18.10-lfs-13.0-systemd root=LABEL=lfs-root ro
    initrd  /boot/initramfs-6.18.10-lfs-13.0-systemd.img
}
EOF
    """,
    deps = [":kernel"],
)

# --------------------------------------------------------------------------- #
# Initramfs (BLFS "About initramfs")
# --------------------------------------------------------------------------- #
#
# Installs the canonical LFS/BLFS mkinitramfs script + init.in byte-verbatim (a
# raw Starlark string keeps their tabs, newlines and line-continuations intact),
# then builds /boot/initramfs-6.18.10-lfs-13.0-systemd.img for the canonical
# kernel. mkinitramfs writes initrd.img-<ver> into the CWD, so cd /boot first,
# then rename to the repo's canonical initramfs filename.

lfs_script(
    name = "mkinitramfs",
    script = r"""
        install -v -dm755 /usr/share/mkinitramfs

        cat > /usr/sbin/mkinitramfs << 'MKINITRAMFS_EOF'
#!/bin/bash
# This file based in part on the mkinitramfs script for the LFS LiveCD
# written by Alexander E. Patrakov and Jeremy Huntwork.

copy()
{
  local file

  if [ "$2" = "lib" ]; then
    file=$(PATH=/usr/lib type -p $1)
  else
    file=$(type -p $1)
  fi

  if [ -n "$file" ] ; then
    cp $file $WDIR/usr/$2
  else
    echo "Missing required file: $1 for directory $2"
    rm -rf $WDIR
    exit 1
  fi
}

if [ -z $1 ] ; then
  INITRAMFS_FILE=initrd.img-no-kmods
else
  KERNEL_VERSION=$1
  INITRAMFS_FILE=initrd.img-$KERNEL_VERSION
fi

if [ -n "$KERNEL_VERSION" ] && [ ! -d "/usr/lib/modules/$1" ] ; then
  echo "No modules directory named $1"
  exit 1
fi

printf "Creating $INITRAMFS_FILE... "

binfiles="sh cat cp dd killall ls mkdir mknod mount "
binfiles="$binfiles umount sed sleep ln rm uname"
binfiles="$binfiles readlink basename"

# Systemd installs udevadm in /bin. Other udev implementations have it in /sbin
if [ -x /usr/bin/udevadm ] ; then binfiles="$binfiles udevadm"; fi

sbinfiles="modprobe blkid switch_root"

# Optional files and locations
for f in mdadm mdmon udevd udevadm; do
  if [ -x /usr/sbin/$f ] ; then sbinfiles="$sbinfiles $f"; fi
done

# Add lvm if present (cannot be done with the others because it
# also needs dmsetup
if [ -x /usr/sbin/lvm ] ; then sbinfiles="$sbinfiles lvm dmsetup"; fi

unsorted=$(mktemp /tmp/unsorted.XXXXXXXXXX)

DATADIR=/usr/share/mkinitramfs
INITIN=init.in

# Create a temporary working directory
WDIR=$(mktemp -d /tmp/initrd-work.XXXXXXXXXX)

# Create base directory structure
mkdir -p $WDIR/{dev,run,sys,proc,usr/{bin,lib/{firmware,modules},sbin}}
mkdir -p $WDIR/etc/{modprobe.d,udev/rules.d}
touch $WDIR/etc/modprobe.d/modprobe.conf
ln -s usr/bin  $WDIR/bin
ln -s usr/lib  $WDIR/lib
ln -s usr/sbin $WDIR/sbin
ln -s lib      $WDIR/lib64

# Create necessary device nodes
mknod -m 640 $WDIR/dev/console c 5 1
mknod -m 664 $WDIR/dev/null    c 1 3

# Install the udev configuration files
if [ -f /etc/udev/udev.conf ]; then
  cp /etc/udev/udev.conf $WDIR/etc/udev/udev.conf
fi

for file in $(find /etc/udev/rules.d/ -type f) ; do
  cp $file $WDIR/etc/udev/rules.d
done

# Install any firmware present
cp -a /usr/lib/firmware $WDIR/usr/lib

# Copy the RAID configuration file if present
if [ -f /etc/mdadm.conf ] ; then
  cp /etc/mdadm.conf $WDIR/etc
fi

# Install the init file
install -m0755 $DATADIR/$INITIN $WDIR/init

if [  -n "$KERNEL_VERSION" ] ; then
  if [ -x /usr/bin/kmod ] ; then
    binfiles="$binfiles kmod"
  else
    binfiles="$binfiles lsmod"
    sbinfiles="$sbinfiles insmod"
  fi
fi

# Install basic binaries
for f in $binfiles ; do
  ldd /usr/bin/$f | sed "s/\t//" | cut -d " " -f1 >> $unsorted
  copy /usr/bin/$f bin
done

for f in $sbinfiles ; do
  ldd /usr/sbin/$f | sed "s/\t//" | cut -d " " -f1 >> $unsorted
  copy $f sbin
done

# Add udevd libraries if not in /usr/sbin
if [ -x /usr/lib/udev/udevd ] ; then
  ldd /usr/lib/udev/udevd | sed "s/\t//" | cut -d " " -f1 >> $unsorted
elif [ -x /usr/lib/systemd/systemd-udevd ] ; then
  ldd /usr/lib/systemd/systemd-udevd | sed "s/\t//" | cut -d " " -f1 >> $unsorted
fi

# Add module symlinks if appropriate
if [ -n "$KERNEL_VERSION" ] && [ -x /usr/bin/kmod ] ; then
  ln -s kmod $WDIR/usr/bin/lsmod
  ln -s kmod $WDIR/usr/bin/insmod
fi

# Add lvm symlinks if appropriate
# Also copy the lvm.conf file
if  [ -x /usr/sbin/lvm ] ; then
  ln -s lvm $WDIR/usr/sbin/lvchange
  ln -s lvm $WDIR/usr/sbin/lvrename
  ln -s lvm $WDIR/usr/sbin/lvextend
  ln -s lvm $WDIR/usr/sbin/lvcreate
  ln -s lvm $WDIR/usr/sbin/lvdisplay
  ln -s lvm $WDIR/usr/sbin/lvscan

  ln -s lvm $WDIR/usr/sbin/pvchange
  ln -s lvm $WDIR/usr/sbin/pvck
  ln -s lvm $WDIR/usr/sbin/pvcreate
  ln -s lvm $WDIR/usr/sbin/pvdisplay
  ln -s lvm $WDIR/usr/sbin/pvscan

  ln -s lvm $WDIR/usr/sbin/vgchange
  ln -s lvm $WDIR/usr/sbin/vgcreate
  ln -s lvm $WDIR/usr/sbin/vgscan
  ln -s lvm $WDIR/usr/sbin/vgrename
  ln -s lvm $WDIR/usr/sbin/vgck
  # Conf file(s)
  cp -a /etc/lvm $WDIR/etc
fi

# Install libraries
sort $unsorted | uniq | while read library ; do
# linux-vdso and linux-gate are pseudo libraries and do not correspond to a file
# libsystemd-shared is in /lib/systemd, so it is not found by copy, and
# it is copied below anyway
  if [[ "$library" == linux-vdso.so.1 ]] ||
     [[ "$library" == linux-gate.so.1 ]] ||
     [[ "$library" == libsystemd-shared* ]]; then
    continue
  fi

  copy $library lib
done

if [ -d /usr/lib/udev ]; then
  cp -a /usr/lib/udev $WDIR/usr/lib
fi
if [ -d /usr/lib/systemd ]; then
  cp -a /usr/lib/systemd $WDIR/usr/lib
fi
if [ -d /usr/lib/elogind ]; then
  cp -a /usr/lib/elogind $WDIR/usr/lib
fi

# Install the kernel modules if requested
if [ -n "$KERNEL_VERSION" ]; then
  find \
     /usr/lib/modules/$KERNEL_VERSION/kernel/{crypto,fs,lib}                      \
     /usr/lib/modules/$KERNEL_VERSION/kernel/drivers/{block,ata,nvme,md,firewire} \
     /usr/lib/modules/$KERNEL_VERSION/kernel/drivers/{scsi,message,pcmcia,virtio} \
     /usr/lib/modules/$KERNEL_VERSION/kernel/drivers/usb/{host,storage}           \
     -type f 2> /dev/null | cpio --make-directories -p --quiet $WDIR

  cp /usr/lib/modules/$KERNEL_VERSION/modules.{builtin,order} \
            $WDIR/usr/lib/modules/$KERNEL_VERSION
  if [ -f /usr/lib/modules/$KERNEL_VERSION/modules.builtin.modinfo ]; then
    cp /usr/lib/modules/$KERNEL_VERSION/modules.builtin.modinfo \
            $WDIR/usr/lib/modules/$KERNEL_VERSION
  fi

  depmod -b $WDIR $KERNEL_VERSION
fi

( cd $WDIR ; find . | cpio -o -H newc --quiet | gzip -9 ) > $INITRAMFS_FILE

# Prepare early loading of microcode if available
if ls /usr/lib/firmware/intel-ucode/* >/dev/null 2>&1 ||
   ls /usr/lib/firmware/amd-ucode/*   >/dev/null 2>&1; then

# first empty WDIR to reuse it
  rm -r $WDIR/*

  DSTDIR=$WDIR/kernel/x86/microcode
  mkdir -p $DSTDIR

  if [ -d /usr/lib/firmware/amd-ucode ]; then
    cat /usr/lib/firmware/amd-ucode/microcode_amd*.bin > $DSTDIR/AuthenticAMD.bin
  fi

  if [ -d /usr/lib/firmware/intel-ucode ]; then
    cat /usr/lib/firmware/intel-ucode/* > $DSTDIR/GenuineIntel.bin
  fi

  ( cd $WDIR; find . | cpio -o -H newc --quiet ) > microcode.img
  cat microcode.img $INITRAMFS_FILE > tmpfile
  mv tmpfile $INITRAMFS_FILE
  rm microcode.img
fi

# Remove the temporary directories and files
rm -rf $WDIR $unsorted
printf "done.\n"
MKINITRAMFS_EOF
        chmod 0755 /usr/sbin/mkinitramfs

        cat > /usr/share/mkinitramfs/init.in << 'INITIN_EOF'
#!/bin/sh

PATH=/usr/bin:/usr/sbin
export PATH

problem()
{
   printf "Encountered a problem!\n\nDropping you to a shell.\n\n"
   sh
}

no_device()
{
   printf "The device %s, which is supposed to contain the\n" $1
   printf "root file system, does not exist.\n"
   printf "Please fix this problem and exit this shell.\n\n"
}

no_mount()
{
   printf "Could not mount device %s\n" $1
   printf "Sleeping forever. Please reboot and fix the kernel command line.\n\n"
   printf "Maybe the device is formatted with an unsupported file system?\n\n"
   printf "Or maybe filesystem type autodetection went wrong, in which case\n"
   printf "you should add the rootfstype=... parameter to the kernel command line.\n\n"
   printf "Available partitions:\n"
}

do_mount_root()
{
   mkdir /.root
   [ -n "$rootflags" ] && rootflags="$rootflags,"
   rootflags="$rootflags$ro"

   case "$root" in
      /dev/*    ) device=$root ;;
      UUID=*    ) eval $root; device="/dev/disk/by-uuid/$UUID" ;;
      PARTUUID=*) eval $root; device="/dev/disk/by-partuuid/$PARTUUID" ;;
      LABEL=*   ) eval $root; device="/dev/disk/by-label/$LABEL" ;;
      ""        ) echo "No root device specified." ; problem ;;
   esac

   while [ ! -b "$device" ] ; do
       no_device $device
       problem
   done

   if ! mount -n -t "$rootfstype" -o "$rootflags" "$device" /.root ; then
       no_mount $device
       cat /proc/partitions
       while true ; do sleep 10000 ; done
   else
       echo "Successfully mounted device $root"
   fi
}

do_try_resume()
{
   case "$resume" in
      UUID=* ) eval $resume; resume="/dev/disk/by-uuid/$UUID"  ;;
      LABEL=*) eval $resume; resume="/dev/disk/by-label/$LABEL" ;;
   esac

   if $noresume || ! [ -b "$resume" ]; then return; fi

   ls -lH "$resume" | ( read x x x x maj min x
       echo -n ${maj%,}:$min > /sys/power/resume )
}

init=/sbin/init
root=
rootdelay=
rootfstype=auto
ro="ro"
rootflags=
device=
resume=
noresume=false

mount -n -t devtmpfs devtmpfs /dev
mount -n -t proc     proc     /proc
mount -n -t sysfs    sysfs    /sys
mount -n -t tmpfs    tmpfs    /run

read -r cmdline < /proc/cmdline

for param in $cmdline ; do
  case $param in
    init=*      ) init=${param#init=}             ;;
    root=*      ) root=${param#root=}             ;;
    rootdelay=* ) rootdelay=${param#rootdelay=}   ;;
    rootfstype=*) rootfstype=${param#rootfstype=} ;;
    rootflags=* ) rootflags=${param#rootflags=}   ;;
    resume=*    ) resume=${param#resume=}         ;;
    noresume    ) noresume=true                   ;;
    ro          ) ro="ro"                         ;;
    rw          ) ro="rw"                         ;;
  esac
done

# udevd location depends on version
if [ -x /sbin/udevd ]; then
  UDEVD=/sbin/udevd
elif [ -x /lib/udev/udevd ]; then
  UDEVD=/lib/udev/udevd
elif [ -x /lib/systemd/systemd-udevd ]; then
  UDEVD=/lib/systemd/systemd-udevd
else
  echo "Cannot find udevd nor systemd-udevd"
  problem
fi

${UDEVD} --daemon --resolve-names=never
udevadm trigger
udevadm settle

if [ -f /etc/mdadm.conf ] ; then mdadm -As                       ; fi
if [ -x /sbin/vgchange  ] ; then /sbin/vgchange -a y > /dev/null ; fi
if [ -n "$rootdelay"    ] ; then sleep "$rootdelay"              ; fi

do_try_resume # This function will not return if resuming from disk
do_mount_root

killall -w ${UDEVD##*/}

exec switch_root /.root "$init" "$@"
INITIN_EOF

        # Generate the initramfs for the canonical kernel; mkinitramfs writes
        # initrd.img-<ver> into the CWD, so cd /boot first, then rename.
        cd /boot
        mkinitramfs 6.18.10-lfs-13.0-systemd
        mv /boot/initrd.img-6.18.10-lfs-13.0-systemd /boot/initramfs-6.18.10-lfs-13.0-systemd.img
    """,
    deps = [
        ":kernel",
        "//packages/chapter_08:cpio",
    ],
)

# --------------------------------------------------------------------------- #
# UEFI Bootloader (BLFS GRUB for EFI, grub-mkstandalone)
# --------------------------------------------------------------------------- #
#
# Builds a single standalone GRUB EFI binary at /boot/EFI/BOOT/BOOT*.EFI with
# an embedded grub.cfg. This is the primary self-boot path: firmware runs the
# removable-media fallback \\EFI\\BOOT\\BOOT*.EFI, whose embedded config
# resolves the root fs by LABEL=lfs-root and loads the kernel + initramfs -- no
# efibootmgr/NVRAM entry needed, so it stays rootless. Empty --fonts/--themes/
# --locales avoid font/theme assets our GRUB was built without.

lfs_script(
    name = "efi_bootloader",
    script = """
        mkdir -pv /boot/EFI/BOOT
        case $(uname -m) in
          x86_64) grub_platform=x86_64-efi; efi_binary=BOOTX64.EFI ;;
          aarch64) grub_platform=arm64-efi; efi_binary=BOOTAA64.EFI ;;
          *) echo "unsupported EFI GRUB platform: $(uname -m)" >&2; exit 1 ;;
        esac

        cat > /tmp/grub-embed.cfg << "EOF"
set default=0
set timeout=5
set gfxpayload=1024x768x32
insmod all_video
search --no-floppy --label lfs-root --set=root
menuentry "GNU/Linux, Linux 6.18.10-lfs-13.0-systemd (UEFI)" {
    linux  ($root)/boot/vmlinuz-6.18.10-lfs-13.0-systemd root=LABEL=lfs-root ro
    initrd ($root)/boot/initramfs-6.18.10-lfs-13.0-systemd.img
}
EOF

        grub-mkstandalone \\
            -O "$grub_platform" \\
            -d "/usr/lib/grub/$grub_platform" \\
            -o "/boot/EFI/BOOT/$efi_binary" \\
            --fonts="" --themes="" --locales="" \\
            --modules="part_gpt part_msdos ext2 fat search search_fs_uuid search_label linux normal configfile echo ls all_video gfxterm boot test cat halt reboot" \\
            "boot/grub/grub.cfg=/tmp/grub-embed.cfg"
    """,
    deps = [
        "//packages/chapter_08:grub_efi",
        ":mkinitramfs",
    ],
)

# --------------------------------------------------------------------------- #
# Chapter 10 Aggregate
# --------------------------------------------------------------------------- #

filegroup(
    name = "chapter_10",
    srcs = [
        ":efi_bootloader",
        ":grub_config",
        ":kernel",
        ":mkinitramfs",
    ],
)
