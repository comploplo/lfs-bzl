load("@rules_cc//cc:cc_test.bzl", "cc_test")

package(default_visibility = ["//visibility:public"])

cc_test(
    name = "version_check_test",
    srcs = ["version_check_test.cc"],
    copts = ["-std=c++17"],
    tags = [
        "local",
        "no-sandbox",
    ],
)
