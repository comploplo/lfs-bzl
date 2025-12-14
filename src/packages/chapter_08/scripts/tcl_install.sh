#!/bin/bash
set -euo pipefail

# Script: tcl_install.sh
# Purpose: Install Tcl with private headers and config fixes

cd unix
make install

# Make library writable for debugging symbols
chmod -v u+w /usr/lib/libtcl8.6.so

# Install private headers (needed by Expect)
make install-private-headers

# Create symlink
ln -sfv tclsh8.6 /usr/bin/tclsh

# Rename conflicting man page
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
