#include <array>
#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <utility>
#include <vector>

namespace fs = std::filesystem;

namespace
{

struct Version {
    std::vector<int> parts;
    std::string suffix;
};

Version ParseVersion(std::string_view raw)
{
    Version v;
    std::stringstream ss{std::string(raw)};
    std::string token;
    while (std::getline(ss, token, '.')) {
        size_t i = 0;
        while (i < token.size() && std::isdigit(static_cast<unsigned char>(token[i]))) {
            ++i;
        }
        int num = 0;
        if (i > 0) {
            num = std::stoi(token.substr(0, i));
        }
        v.parts.push_back(num);
        if (i < token.size()) {
            // Capture trailing letter(s) on the last numeric token.
            v.suffix = token.substr(i);
        }
    }
    return v;
}

bool VersionAtLeast(std::string_view actual, std::string_view minimum)
{
    Version a = ParseVersion(actual);
    Version m = ParseVersion(minimum);
    size_t count = std::max(a.parts.size(), m.parts.size());
    a.parts.resize(count, 0);
    m.parts.resize(count, 0);
    for (size_t i = 0; i < count; ++i) {
        if (a.parts[i] > m.parts[i])
            return true;
        if (a.parts[i] < m.parts[i])
            return false;
    }
    // Numbers equal, compare suffixes (if any).
    if (a.suffix == m.suffix)
        return true;
    if (a.suffix.empty() && !m.suffix.empty())
        return false;
    if (!a.suffix.empty() && m.suffix.empty())
        return true;
    return a.suffix >= m.suffix;
}

std::optional<std::string> CaptureCommand(std::string cmd)
{
    cmd += " 2>&1";  // capture stderr too
    std::array<char, 4096> buf{};
    std::string out;
    FILE *pipe = popen(cmd.c_str(), "r");
    if (!pipe) {
        std::cerr << "FAIL: popen for command: " << cmd << " (" << std::strerror(errno) << ")\n";
        return std::nullopt;
    }
    while (fgets(buf.data(), buf.size(), pipe)) {
        out.append(buf.data());
    }
    int rc = pclose(pipe);
    if (rc != 0) {
        std::cerr << "FAIL: command exited with status " << rc << ": " << cmd << "\n";
        return std::nullopt;
    }
    return out;
}

std::optional<std::string> ExtractVersion(std::string_view text)
{
    static const std::regex re("[0-9]+\\.[0-9A-Za-z\\.]*");
    std::cmatch match;
    if (std::regex_search(text.begin(), text.end(), match, re)) {
        return match.str(0);
    }
    return std::nullopt;
}

bool ContainsCaseInsensitive(std::string_view haystack, std::string_view needle)
{
    auto tolower_str = [](std::string_view s) {
        std::string out(s.size(), '\0');
        for (size_t i = 0; i < s.size(); ++i)
            out[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(s[i])));
        return out;
    };
    std::string h = tolower_str(haystack);
    std::string n = tolower_str(needle);
    return h.find(n) != std::string::npos;
}

struct Requirement {
    std::string name;
    std::string command;
    std::string minimum_version;
};

int CheckVersionedTools()
{
    const std::vector<Requirement> reqs = {
        {"Coreutils (sort)", "sort --version", "8.1"},
        {"Bash", "bash --version", "3.2"},
        {"Binutils (ld)", "ld --version", "2.13.1"},
        {"Bison", "bison --version", "2.7"},
        {"Diffutils", "diff --version", "2.8.1"},
        {"Findutils", "find --version", "4.2.31"},
        {"Gawk", "gawk --version", "4.0.1"},
        {"GCC", "gcc --version", "5.4"},
        {"GCC (C++)", "g++ --version", "5.4"},
        {"Grep", "grep --version", "2.5.1a"},
        {"Gzip", "gzip --version", "1.3.12"},
        {"M4", "m4 --version", "1.4.10"},
        {"Make", "make --version", "4.0"},
        {"Patch", "patch --version", "2.5.4"},
        {"Perl", "perl -V:version", "5.8.8"},
        {"Python", "python3 --version", "3.4"},
        {"Sed", "sed --version", "4.1.5"},
        {"Tar", "tar --version", "1.22"},
        {"Texinfo (texi2any)", "texi2any --version", "5.0"},
        {"Xz", "xz --version", "5.0.0"},
    };

    int failures = 0;
    for (const auto &r : reqs) {
        auto out = CaptureCommand(r.command);
        if (!out) {
            std::cerr << "ERROR: cannot run " << r.name << " command\n";
            ++failures;
            continue;
        }
        auto ver = ExtractVersion(*out);
        if (!ver) {
            std::cerr << "ERROR: cannot parse version for " << r.name << "\n";
            ++failures;
            continue;
        }
        if (!VersionAtLeast(*ver, r.minimum_version)) {
            std::cerr << "ERROR: " << r.name << " version " << *ver << " < required "
                      << r.minimum_version << "\n";
            ++failures;
            continue;
        }
        std::cout << "OK:    " << r.name << " " << *ver << " >= " << r.minimum_version << "\n";
    }
    return failures;
}

int CheckAliases()
{
    const std::vector<std::pair<std::string, std::string>> aliases = {
        {"awk", "GNU"},
        {"yacc", "Bison"},
        {"sh", "Bash"},
    };

    int failures = 0;
    for (const auto &[cmd, expected] : aliases) {
        auto out = CaptureCommand(cmd + " --version");
        if (!out || !ContainsCaseInsensitive(*out, expected)) {
            std::cerr << "ERROR: " << cmd << " is not " << expected << "\n";
            ++failures;
        } else {
            std::cout << "OK:    " << cmd << " is " << expected << "\n";
        }
    }
    return failures;
}

int CheckKernel()
{
    struct utsname buf{};
    if (uname(&buf) != 0) {
        std::cerr << "ERROR: uname failed: " << std::strerror(errno) << "\n";
        return 1;
    }
    std::string release = buf.release;
    auto ver = ExtractVersion(release);
    if (!ver || !VersionAtLeast(*ver, "5.4")) {
        std::cerr << "ERROR: Linux kernel (" << release << ") is TOO OLD (5.4 or later required)\n";
        return 1;
    }
    std::cout << "OK:    Linux Kernel " << *ver << " >= 5.4\n";
    // PTY support check.
    bool devpts = false;
    {
        std::ifstream mounts("/proc/mounts");
        std::string line;
        while (std::getline(mounts, line)) {
            if (line.find("devpts /dev/pts") != std::string::npos) {
                devpts = true;
                break;
            }
        }
    }
    if (!devpts || !fs::exists("/dev/ptmx")) {
        std::cerr << "ERROR: Linux Kernel does NOT support UNIX 98 PTY\n";
        return 1;
    }
    std::cout << "OK:    Linux Kernel supports UNIX 98 PTY\n";
    return 0;
}

int CheckCompiler()
{
    const char *tmpdir_env = std::getenv("TEST_TMPDIR");
    fs::path tmpdir = tmpdir_env ? tmpdir_env : "/tmp";
    fs::create_directories(tmpdir);
    fs::path src = tmpdir / "lfs_dummy.cpp";
    fs::path exe = tmpdir / "lfs_dummy";
    {
        std::ofstream out(src);
        out << "int main() { return 0; }\n";
    }
    std::string cmd = "g++ -o " + exe.string() + " " + src.string();
    auto out = CaptureCommand(cmd);
    fs::remove(src);
    fs::remove(exe);
    if (!out) {
        std::cerr << "ERROR: g++ does NOT work\n";
        return 1;
    }
    std::cout << "OK:    g++ works\n";
    return 0;
}

int CheckNproc()
{
    auto out = CaptureCommand("nproc");
    if (!out) {
        std::cerr << "ERROR: nproc is not available\n";
        return 1;
    }
    std::string trimmed = *out;
    auto pos = trimmed.find_last_not_of("\n \t\r");
    if (pos == std::string::npos) {
        std::cerr << "ERROR: nproc produces empty output\n";
        return 1;
    }
    trimmed.erase(pos + 1);
    std::cout << "OK: nproc reports " << trimmed << " logical cores are available\n";
    return 0;
}

}  // namespace

int main()
{
    int failures = 0;
    failures += CheckVersionedTools();
    failures += CheckAliases();
    failures += CheckKernel();
    failures += CheckCompiler();
    failures += CheckNproc();

    if (failures != 0) {
        std::cerr << "Version checks failed: " << failures << " item(s)\n";
        return 1;
    }
    std::cout << "All Chapter 02 host tool checks passed.\n";
    return 0;
}
