#!/bin/bash
set -euo pipefail

# Script: glibc_install.sh
# Purpose: Install glibc with locale setup and configuration files

cd build

# Create ld.so.conf to prevent warning
touch /etc/ld.so.conf

# Skip outdated sanity check
# shellcheck disable=SC2016  # $(PERL) is a Makefile variable, not a shell variable
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

# Install glibc
make install

# Fix hardcoded path in ldd script
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

# Install locale configuration
mkdir -pv /usr/lib/locale
localedef -i C -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

# Create nsswitch.conf
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

# Create /etc/ld.so.conf
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

# Create /etc/ld.so.conf.d directory
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
