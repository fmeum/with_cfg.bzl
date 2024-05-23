load("@contrib_rules_jvm//java:defs.bzl", "java_junit5_test")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(java_junit5_test)
_builder.set("java_language_version", "21").set("java_runtime_version", "remotejdk_21")
java_21_junit5_test, _java_21_junit5_test_internal = _builder.build()
