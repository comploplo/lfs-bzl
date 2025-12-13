#!/usr/bin/env bash
set -euo pipefail

# Matches docs/lfs-book/chapter07/createfiles.xml (System V).
if [ -L /etc/mtab ]; then
  if [ "$(readlink /etc/mtab)" != "/proc/self/mounts" ]; then
    ln -snfv /proc/self/mounts /etc/mtab
  fi
elif [ -e /etc/mtab ]; then
  echo "Error: /etc/mtab exists but is not a symlink; refusing to overwrite" >&2
  echo "Fix by removing it (inside chroot) or set LFS_FORCE_MTAB_SYMLINK=1" >&2
  if [ "${LFS_FORCE_MTAB_SYMLINK:-0}" = "1" ]; then
    ln -snfv /proc/self/mounts /etc/mtab
  else
    exit 1
  fi
else
  ln -sv /proc/self/mounts /etc/mtab
fi

cat > /etc/hosts <<EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

cat > /etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

cat > /etc/group <<'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

localedef -i C -f UTF-8 C.UTF-8

echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp
