resolved = [
     {
          "original_rule_class": "local_repository",
          "original_attributes": {
               "name": "bazel_tools",
               "path": "/home/gabe/.cache/bazel/_bazel_gabe/install/eb6bebcb4f9bcd23452d653bb61ca1b0/embedded_tools"
          },
          "native": "local_repository(name = \"bazel_tools\", path = __embedded_dir__ + \"/\" + \"embedded_tools\")"
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:local.bzl%local_repository",
          "definition_information": "Repository internal_platforms_do_not_use instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:53:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule local_repository defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/local.bzl:66:35: in <toplevel>\n",
          "original_attributes": {
               "name": "internal_platforms_do_not_use",
               "generator_name": "internal_platforms_do_not_use",
               "generator_function": "maybe",
               "generator_location": None,
               "path": "/home/gabe/.cache/bazel/_bazel_gabe/install/eb6bebcb4f9bcd23452d653bb61ca1b0/platforms"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:local.bzl%local_repository",
                    "attributes": {
                         "name": "internal_platforms_do_not_use",
                         "generator_name": "internal_platforms_do_not_use",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "path": "/home/gabe/.cache/bazel/_bazel_gabe/install/eb6bebcb4f9bcd23452d653bb61ca1b0/platforms"
                    },
                    "output_tree_hash": "c44e62e0a1854354e68c5d2182de144682a2d6be739eb108fc73e5fe0e45f9c7"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository rules_cc instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:72:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "rules_cc",
               "generator_name": "rules_cc",
               "generator_function": "maybe",
               "generator_location": None,
               "urls": [
                    "https://github.com/bazelbuild/rules_cc/releases/download/0.0.16/rules_cc-0.0.16.tar.gz"
               ],
               "sha256": "bbf1ae2f83305b7053b11e4467d317a7ba3517a12cef608543c1b1c5bf48a4df",
               "strip_prefix": "rules_cc-0.0.16"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "rules_cc",
                         "generator_name": "rules_cc",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "urls": [
                              "https://github.com/bazelbuild/rules_cc/releases/download/0.0.16/rules_cc-0.0.16.tar.gz"
                         ],
                         "sha256": "bbf1ae2f83305b7053b11e4467d317a7ba3517a12cef608543c1b1c5bf48a4df",
                         "strip_prefix": "rules_cc-0.0.16"
                    },
                    "output_tree_hash": "c3a5bf545153d3edff812dd656ac20cfbd6b3029b68b51bcb768fc9ffded4276"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository rules_java instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:104:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "rules_java",
               "generator_name": "rules_java",
               "generator_function": "maybe",
               "generator_location": None,
               "urls": [
                    "https://github.com/bazelbuild/rules_java/releases/download/8.12.0/rules_java-8.12.0.tar.gz"
               ],
               "sha256": "1558508fc6c348d7f99477bd21681e5746936f15f0436b5f4233e30832a590f9"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "rules_java",
                         "generator_name": "rules_java",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "urls": [
                              "https://github.com/bazelbuild/rules_java/releases/download/8.12.0/rules_java-8.12.0.tar.gz"
                         ],
                         "sha256": "1558508fc6c348d7f99477bd21681e5746936f15f0436b5f4233e30832a590f9"
                    },
                    "output_tree_hash": "7f10936296a81d1a6273dfb506920b04ddcbd886d5aa3bcfd30c1e0e10a8ba76"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository bazel_features instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:137:24: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_java/java/rules_java_deps.bzl:235:24: in rules_java_dependencies\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_java/java/rules_java_deps.bzl:214:10: in bazel_features_repo\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "bazel_features",
               "generator_name": "bazel_features",
               "generator_function": "rules_java_dependencies",
               "generator_location": None,
               "url": "https://github.com/bazel-contrib/bazel_features/releases/download/v1.30.0/bazel_features-v1.30.0.tar.gz",
               "sha256": "a660027f5a87f13224ab54b8dc6e191693c554f2692fcca46e8e29ee7dabc43b",
               "strip_prefix": "bazel_features-1.30.0"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "bazel_features",
                         "generator_name": "bazel_features",
                         "generator_function": "rules_java_dependencies",
                         "generator_location": None,
                         "url": "https://github.com/bazel-contrib/bazel_features/releases/download/v1.30.0/bazel_features-v1.30.0.tar.gz",
                         "sha256": "a660027f5a87f13224ab54b8dc6e191693c554f2692fcca46e8e29ee7dabc43b",
                         "strip_prefix": "bazel_features-1.30.0"
                    },
                    "output_tree_hash": "6a43c5b8f662cac3248443da4b7eca4405ef43d2be90984008c9b8a74ec235b7"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository rules_python instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:120:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "rules_python",
               "generator_name": "rules_python",
               "generator_function": "maybe",
               "generator_location": None,
               "urls": [
                    "https://github.com/bazelbuild/rules_python/releases/download/0.40.0/rules_python-0.40.0.tar.gz"
               ],
               "sha256": "690e0141724abb568267e003c7b6d9a54925df40c275a870a4d934161dc9dd53",
               "strip_prefix": "rules_python-0.40.0"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "rules_python",
                         "generator_name": "rules_python",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "urls": [
                              "https://github.com/bazelbuild/rules_python/releases/download/0.40.0/rules_python-0.40.0.tar.gz"
                         ],
                         "sha256": "690e0141724abb568267e003c7b6d9a54925df40c275a870a4d934161dc9dd53",
                         "strip_prefix": "rules_python-0.40.0"
                    },
                    "output_tree_hash": "bc207a852d970a6d1335fa26803f3cc175c22ed56a2c13cd392b0bcaa8fcc3f7"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository com_google_protobuf instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:96:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "com_google_protobuf",
               "generator_name": "com_google_protobuf",
               "generator_function": "maybe",
               "generator_location": None,
               "urls": [
                    "https://github.com/protocolbuffers/protobuf/releases/download/v29.0-rc3/protobuf-29.0-rc3.zip"
               ],
               "sha256": "537d1c4edb6cbfa96d98a021650e3c455fffcf80dbdcea7fe46cb356e6e9732d",
               "strip_prefix": "protobuf-29.0-rc3"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "com_google_protobuf",
                         "generator_name": "com_google_protobuf",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "urls": [
                              "https://github.com/protocolbuffers/protobuf/releases/download/v29.0-rc3/protobuf-29.0-rc3.zip"
                         ],
                         "sha256": "537d1c4edb6cbfa96d98a021650e3c455fffcf80dbdcea7fe46cb356e6e9732d",
                         "strip_prefix": "protobuf-29.0-rc3"
                    },
                    "output_tree_hash": "35a4214de7176b71cf6ab0adec849ea402faf37dcd22c84794d284c567fd3e27"
               }
          ]
     },
     {
          "original_rule_class": "@@rules_java//java:rules_java_deps.bzl%_compatibility_proxy_repo_rule",
          "definition_information": "Repository compatibility_proxy instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:137:24: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_java/java/rules_java_deps.bzl:227:29: in rules_java_dependencies\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_java/java/rules_java_deps.bzl:114:10: in compatibility_proxy_repo\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule _compatibility_proxy_repo_rule defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_java/java/rules_java_deps.bzl:107:49: in <toplevel>\n",
          "original_attributes": {
               "name": "compatibility_proxy",
               "generator_name": "compatibility_proxy",
               "generator_function": "rules_java_dependencies",
               "generator_location": None
          },
          "repositories": [
               {
                    "rule_class": "@@rules_java//java:rules_java_deps.bzl%_compatibility_proxy_repo_rule",
                    "attributes": {
                         "name": "compatibility_proxy",
                         "generator_name": "compatibility_proxy",
                         "generator_function": "rules_java_dependencies",
                         "generator_location": None
                    },
                    "output_tree_hash": "ebbbc4825c01582ab216dbce529d9253adc5f4004c5de360474438b104769c7e"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository bazel_skylib instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:88:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "bazel_skylib",
               "generator_name": "bazel_skylib",
               "generator_function": "maybe",
               "generator_location": None,
               "urls": [
                    "https://github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz"
               ],
               "sha256": "9f38886a40548c6e96c106b752f242130ee11aaa068a56ba7e56f4511f33e4f2"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "bazel_skylib",
                         "generator_name": "bazel_skylib",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "urls": [
                              "https://github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz"
                         ],
                         "sha256": "9f38886a40548c6e96c106b752f242130ee11aaa068a56ba7e56f4511f33e4f2"
                    },
                    "output_tree_hash": "fae930d1d51ea9a75f1f3ab3edc23892f9095ffb78b1f598b5db7563053b899d"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_features//private:version_repo.bzl%version_repo",
          "definition_information": "Repository bazel_features_version instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:139:20: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/deps.bzl:8:25: in bazel_features_deps\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/private/repos.bzl:9:10: in bazel_features_repos\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule version_repo defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/private/version_repo.bzl:20:31: in <toplevel>\n",
          "original_attributes": {
               "name": "bazel_features_version",
               "generator_name": "bazel_features_version",
               "generator_function": "bazel_features_deps",
               "generator_location": None
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_features//private:version_repo.bzl%version_repo",
                    "attributes": {
                         "name": "bazel_features_version",
                         "generator_name": "bazel_features_version",
                         "generator_function": "bazel_features_deps",
                         "generator_location": None
                    },
                    "output_tree_hash": "f7e037c76644a36a35437e8ffc61db400913736a561e3b8a70fd7e730bb10d30"
               }
          ]
     },
     {
          "original_rule_class": "@@com_google_protobuf//bazel/private:proto_bazel_features.bzl%proto_bazel_features",
          "definition_information": "Repository proto_bazel_features instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:143:14: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/com_google_protobuf/protobuf_deps.bzl:116:29: in protobuf_deps\nRepository rule proto_bazel_features defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/com_google_protobuf/bazel/private/proto_bazel_features.bzl:55:39: in <toplevel>\n",
          "original_attributes": {
               "name": "proto_bazel_features",
               "generator_name": "proto_bazel_features",
               "generator_function": "protobuf_deps",
               "generator_location": None
          },
          "repositories": [
               {
                    "rule_class": "@@com_google_protobuf//bazel/private:proto_bazel_features.bzl%proto_bazel_features",
                    "attributes": {
                         "name": "proto_bazel_features",
                         "generator_name": "proto_bazel_features",
                         "generator_function": "protobuf_deps",
                         "generator_location": None
                    },
                    "output_tree_hash": "e4a69efee76a55f1bf8a656ff4d7c4fbd156046708511a440d0ae56d45c71b65"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_features//private:globals_repo.bzl%globals_repo",
          "definition_information": "Repository bazel_features_globals instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:139:20: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/deps.bzl:8:25: in bazel_features_deps\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/private/repos.bzl:13:10: in bazel_features_repos\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule globals_repo defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_features/private/globals_repo.bzl:46:31: in <toplevel>\n",
          "original_attributes": {
               "name": "bazel_features_globals",
               "generator_name": "bazel_features_globals",
               "generator_function": "bazel_features_deps",
               "generator_location": None,
               "globals": {
                    "CcSharedLibraryInfo": "6.0.0-pre.20220630.1",
                    "CcSharedLibraryHintInfo": "7.0.0-pre.20230316.2",
                    "macro": "8.0.0",
                    "PackageSpecificationInfo": "6.4.0",
                    "RunEnvironmentInfo": "5.3.0",
                    "subrule": "7.0.0",
                    "DefaultInfo": "0.0.1",
                    "__TestingOnly_NeverAvailable": "1000000000.0.0"
               },
               "legacy_globals": {
                    "JavaInfo": "8.0.0",
                    "JavaPluginInfo": "8.0.0",
                    "ProtoInfo": "8.0.0",
                    "PyCcLinkParamsProvider": "8.0.0",
                    "PyInfo": "8.0.0",
                    "PyRuntimeInfo": "8.0.0",
                    "cc_proto_aspect": "8.0.0"
               }
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_features//private:globals_repo.bzl%globals_repo",
                    "attributes": {
                         "name": "bazel_features_globals",
                         "generator_name": "bazel_features_globals",
                         "generator_function": "bazel_features_deps",
                         "generator_location": None,
                         "globals": {
                              "CcSharedLibraryInfo": "6.0.0-pre.20220630.1",
                              "CcSharedLibraryHintInfo": "7.0.0-pre.20230316.2",
                              "macro": "8.0.0",
                              "PackageSpecificationInfo": "6.4.0",
                              "RunEnvironmentInfo": "5.3.0",
                              "subrule": "7.0.0",
                              "DefaultInfo": "0.0.1",
                              "__TestingOnly_NeverAvailable": "1000000000.0.0"
                         },
                         "legacy_globals": {
                              "JavaInfo": "8.0.0",
                              "JavaPluginInfo": "8.0.0",
                              "ProtoInfo": "8.0.0",
                              "PyCcLinkParamsProvider": "8.0.0",
                              "PyInfo": "8.0.0",
                              "PyRuntimeInfo": "8.0.0",
                              "cc_proto_aspect": "8.0.0"
                         }
                    },
                    "output_tree_hash": "6b2cc2db574126ef2b694118e829b9a0232e280edb6e1b0b24fbb3185f9cce40"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
          "definition_information": "Repository rules_shell instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:143:14: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/com_google_protobuf/protobuf_deps.bzl:108:21: in protobuf_deps\nRepository rule http_archive defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/http.bzl:431:31: in <toplevel>\n",
          "original_attributes": {
               "name": "rules_shell",
               "generator_name": "rules_shell",
               "generator_function": "protobuf_deps",
               "generator_location": None,
               "url": "https://github.com/bazelbuild/rules_shell/releases/download/v0.2.0/rules_shell-v0.2.0.tar.gz",
               "sha256": "410e8ff32e018b9efd2743507e7595c26e2628567c42224411ff533b57d27c28",
               "strip_prefix": "rules_shell-0.2.0"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:http.bzl%http_archive",
                    "attributes": {
                         "name": "rules_shell",
                         "generator_name": "rules_shell",
                         "generator_function": "protobuf_deps",
                         "generator_location": None,
                         "url": "https://github.com/bazelbuild/rules_shell/releases/download/v0.2.0/rules_shell-v0.2.0.tar.gz",
                         "sha256": "410e8ff32e018b9efd2743507e7595c26e2628567c42224411ff533b57d27c28",
                         "strip_prefix": "rules_shell-0.2.0"
                    },
                    "output_tree_hash": "280d9c3fa766f159ad881810b0dc7cc4144c8351326b94493912bacc50f96b24"
               }
          ]
     },
     {
          "original_rule_class": "@@rules_python//python/private:internal_config_repo.bzl%internal_config_repo",
          "definition_information": "Repository rules_python_internal instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:141:16: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_python/python/private/py_repositories.bzl:33:10: in py_repositories\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule internal_config_repo defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/rules_python/python/private/internal_config_repo.bzl:108:39: in <toplevel>\n",
          "original_attributes": {
               "name": "rules_python_internal",
               "generator_name": "rules_python_internal",
               "generator_function": "py_repositories",
               "generator_location": None
          },
          "repositories": [
               {
                    "rule_class": "@@rules_python//python/private:internal_config_repo.bzl%internal_config_repo",
                    "attributes": {
                         "name": "rules_python_internal",
                         "generator_name": "rules_python_internal",
                         "generator_function": "py_repositories",
                         "generator_location": None
                    },
                    "output_tree_hash": "0193d47cf06e9de28a088056a4f82c51c5373a113bc731952eab6da87ce40f25"
               }
          ]
     },
     {
          "original_rule_class": "@@bazel_tools//tools/build_defs/repo:local.bzl%local_repository",
          "definition_information": "Repository platforms instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:47:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule local_repository defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/local.bzl:66:35: in <toplevel>\n",
          "original_attributes": {
               "name": "platforms",
               "generator_name": "platforms",
               "generator_function": "maybe",
               "generator_location": None,
               "path": "/home/gabe/.cache/bazel/_bazel_gabe/install/eb6bebcb4f9bcd23452d653bb61ca1b0/platforms"
          },
          "repositories": [
               {
                    "rule_class": "@@bazel_tools//tools/build_defs/repo:local.bzl%local_repository",
                    "attributes": {
                         "name": "platforms",
                         "generator_name": "platforms",
                         "generator_function": "maybe",
                         "generator_location": None,
                         "path": "/home/gabe/.cache/bazel/_bazel_gabe/install/eb6bebcb4f9bcd23452d653bb61ca1b0/platforms"
                    },
                    "output_tree_hash": "c44e62e0a1854354e68c5d2182de144682a2d6be739eb108fc73e5fe0e45f9c7"
               }
          ]
     },
     {
          "original_rule_class": "@@internal_platforms_do_not_use//host:extension.bzl%host_platform_repo",
          "definition_information": "Repository host_platform instantiated at:\n  /DEFAULT.WORKSPACE.SUFFIX:65:6: in <toplevel>\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/bazel_tools/tools/build_defs/repo/utils.bzl:272:18: in maybe\nRepository rule host_platform_repo defined at:\n  /home/gabe/.cache/bazel/_bazel_gabe/c218c2aca191d483f1a8c4dadd205f2e/external/internal_platforms_do_not_use/host/extension.bzl:53:37: in <toplevel>\n",
          "original_attributes": {
               "name": "host_platform",
               "generator_name": "host_platform",
               "generator_function": "maybe",
               "generator_location": None
          },
          "repositories": [
               {
                    "rule_class": "@@internal_platforms_do_not_use//host:extension.bzl%host_platform_repo",
                    "attributes": {
                         "name": "host_platform",
                         "generator_name": "host_platform",
                         "generator_function": "maybe",
                         "generator_location": None
                    },
                    "output_tree_hash": "7bb7732a410e479305fb8602fbfbe14a04e932eed9f8384852c03def646e87d5"
               }
          ]
     }
]
