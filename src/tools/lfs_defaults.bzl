"""
Common defaults for LFS build phases.

These presets centralize the repeated settings for configure/make/install so
macros can stay declarative and avoid long shell heredocs per package.
"""

# Phase presets keyed by chapter/phase identifier.
PHASE_DEFAULTS = {
    # Chapter 5: cross toolchain (installs into $LFS/tools)
    "ch5": {
        "prefix": "/tools",
        "destdir": "$LFS",
        "build_subdir": "build",
        "make_flags": ["-j$(nproc)"],
    },
    # Chapter 6: temporary tools (installs into $LFS/usr)
    "ch6": {
        "prefix": "/usr",
        "destdir": "$LFS",
        "build_subdir": "build",
        "make_flags": ["-j$(nproc)"],
    },
    # Chapter 7+: inside chroot (installs into /usr)
    "ch7": {
        "prefix": "/usr",
        "destdir": "/",
        "build_subdir": "build",
        "make_flags": ["-j$(nproc)"],
    },
}

def phase_defaults(phase):
    """Return defaults for a phase, falling back to ch6."""
    return PHASE_DEFAULTS.get(phase, PHASE_DEFAULTS["ch6"])
