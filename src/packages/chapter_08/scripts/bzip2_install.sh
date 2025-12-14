#!/bin/bash
set -euo pipefail

# Script: bzip2_install.sh
# Purpose: Install bzip2 with shared library and symlinks

make PREFIX=/usr install

# Install shared library
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so

# Install shared bzip2 binary
cp -v bzip2-shared /usr/bin/bzip2

# Create symlinks
for i in /usr/bin/{bzcat,bunzip2}; do
    ln -sfv bzip2 "$i"
done

# Remove static library
rm -fv /usr/lib/libbz2.a
