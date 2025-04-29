load("@rules_java//java:java_library.bzl", "java_library")
load("@rules_java//java:java_test.bzl", "java_test")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(java_library)
_builder.set("java_language_version", "21").set("java_runtime_version", "remotejdk_21")
_builder.resettable(Label(":java_21_library_original_settings"))
java_21_library, java_21_library_reset = _builder.build()

_test_builder = with_cfg(java_test)
_test_builder.set("java_language_version", "21").set("java_runtime_version", "remotejdk_21")
_test_builder.resettable(Label(":java_21_test_original_settings"))
_test_builder.reset_on_attrs("deps", "runtime_deps")
java_21_test, java_21_test_reset = _test_builder.build()
