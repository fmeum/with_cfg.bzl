load("@bazel_skylib//lib:modules.bzl", "modules")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_jar")

def _protobuf_java_repo():
    http_jar(
        name = "protobuf_java",
        urls = ["https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/4.26.1/protobuf-java-4.26.1.jar"],
        integrity = "sha256-CRkz5YcK+BB0gyb3rOSmc6ynISUxd1QoQvBEtUbxQoI=",
    )

protobuf_java_repo = modules.as_extension(_protobuf_java_repo)
