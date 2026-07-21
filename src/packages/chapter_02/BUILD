load("@rules_python//python:defs.bzl", "py_test")
load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

py_test(
    name = "podman_check_test",
    srcs = ["podman_check_test.py"],
    tags = [
        "local",
        "no-sandbox",
    ],
)

lfs_script(
    name = "version_check",
    phase = "ch5",
    script = """
        set -e
        PASS=0
        FAIL=0

        check_version() {
            local name="$1" cmd="$2" min="$3"
            local ver
            ver=$($cmd 2>&1 | grep -oP '\\d+\\.\\d+(\\.\\d+)?' | head -1) || true
            if [ -z "$ver" ]; then
                echo "FAIL: $name - command '$cmd' failed or version not found"
                FAIL=$((FAIL + 1))
                return
            fi

            if printf '%s\\n%s\\n' "$min" "$ver" | sort -V -C; then
                echo "OK:   $name $ver >= $min"
                PASS=$((PASS + 1))
            else
                echo "FAIL: $name $ver < $min (required >= $min)"
                FAIL=$((FAIL + 1))
            fi
        }

        echo "=== LFS Container Tool Version Check ==="
        check_version "Bash"       "bash --version"      "3.2"
        check_version "Binutils"   "ld --version"        "2.13.1"
        check_version "Bison"      "bison --version"     "2.7"
        check_version "Coreutils"  "sort --version"      "8.1"
        check_version "Diffutils"  "diff --version"      "2.8.1"
        check_version "Findutils"  "find --version"      "4.2.31"
        check_version "Gawk"       "gawk --version"      "4.0.1"
        check_version "GCC"        "gcc --version"       "5.4"
        check_version "G++"        "g++ --version"       "5.4"
        check_version "Grep"       "grep --version"      "2.5.1"
        check_version "Gzip"       "gzip --version"      "1.3.12"
        check_version "M4"         "m4 --version"        "1.4.10"
        check_version "Make"       "make --version"      "4.0"
        check_version "Patch"      "patch --version"     "2.5.4"
        check_version "Perl"       "perl -V:version"     "5.8.8"
        check_version "Python"     "python3 --version"   "3.4"
        check_version "Sed"        "sed --version"       "4.1.5"
        check_version "Tar"        "tar --version"       "1.22"
        check_version "Texinfo"    "texi2any --version"  "5.0"
        check_version "Xz"         "xz --version"        "5.0.0"

        # Compiler sanity check
        echo "int main() { return 0; }" > /tmp/lfs_test.c
        if gcc -o /tmp/lfs_test /tmp/lfs_test.c 2>/dev/null; then
            echo "OK:   GCC compilation works"
            PASS=$((PASS + 1))
            rm -f /tmp/lfs_test /tmp/lfs_test.c
        else
            echo "FAIL: GCC compilation failed"
            FAIL=$((FAIL + 1))
        fi

        # C++ standard libraries with headers (book's g++ pipe-compile test)
        if printf 'int main(){}' | g++ -x c++ - -o /tmp/lfs_test_cxx 2>/dev/null; then
            echo "OK:   g++ compilation works"
            PASS=$((PASS + 1))
            rm -f /tmp/lfs_test_cxx
        else
            echo "FAIL: g++ compilation failed"
            FAIL=$((FAIL + 1))
        fi

        # Required aliases: /bin/sh->bash, /usr/bin/yacc->bison, /usr/bin/awk->gawk
        alias_check() {
            if $1 --version 2>&1 | grep -qi "$2"; then
                echo "OK:   $1 is $2"
                PASS=$((PASS + 1))
            else
                echo "FAIL: $1 is NOT $2"
                FAIL=$((FAIL + 1))
            fi
        }
        alias_check awk  GNU
        alias_check yacc Bison
        alias_check sh   Bash

        echo ""
        echo "=== Results: $PASS passed, $FAIL failed ==="

        if [ "$FAIL" -gt 0 ]; then
            echo "ERROR: Container is missing required tools"
            exit 1
        fi
    """,
)
