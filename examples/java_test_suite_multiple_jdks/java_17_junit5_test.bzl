load("@contrib_rules_jvm//java:defs.bzl", "java_junit5_test")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(java_junit5_test)
_builder.set("java_language_version", "17").set("java_runtime_version", "remotejdk_17")
java_17_junit5_test, _java_17_junit5_test_internal = _builder.build()
