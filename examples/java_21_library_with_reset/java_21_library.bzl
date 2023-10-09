load("@with_cfg.bzl", "with_cfg")

java_21_library, java_21_library_reset = with_cfg(
    native.java_library,
).set(
    "java_language_version",
    "21",
).set(
    "java_runtime_version",
    "remotejdk_21",
).resettable(
    Label(":java_21_library_original_settings"),
).build()
