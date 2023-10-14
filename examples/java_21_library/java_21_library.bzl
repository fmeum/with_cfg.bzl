load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.java_library)
_builder.set("java_language_version", "21").set("java_runtime_version", "remotejdk_21")
java_21_library, _java_21_library_internal = _builder.build()
