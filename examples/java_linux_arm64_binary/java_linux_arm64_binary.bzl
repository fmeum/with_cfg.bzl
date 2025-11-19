load("@rules_java//java:java_binary.bzl", "java_binary")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(java_binary)
_builder.set("platforms", [Label("//java_linux_arm64_binary:linux_arm64")])
java_linux_arm64_binary, _ = _builder.build()
