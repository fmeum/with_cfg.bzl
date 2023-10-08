load("@with_cfg.bzl", "with_cfg")

java_21_library, _java_21_library_internal = with_cfg(
    native.java_library,
).set(
    "java_language_version",
    "21",
).set(
    "java_runtime_version",
    "remotejdk_21",
).build()
