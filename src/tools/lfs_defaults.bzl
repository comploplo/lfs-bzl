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
    # Chroot phase: Podman worker-based builds (Ch7-8+)
    "chroot": {
        "prefix": "/usr",
        "destdir": "/",
        "build_subdir": "build",
        "make_flags": ["-j$(nproc)"],
    },
}

def phase_defaults(phase):
    """Return defaults for a phase."""
    if phase not in PHASE_DEFAULTS:
        fail("Unknown phase '{}'. Must be one of: {}".format(
            phase, ", ".join(PHASE_DEFAULTS.keys())))
    return PHASE_DEFAULTS[phase]
