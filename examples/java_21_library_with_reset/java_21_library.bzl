load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.java_library)
_builder.set("java_language_version", "21").set("java_runtime_version", "remotejdk_21")
_builder.resettable(Label(":java_21_library_original_settings"))
java_21_library, java_21_library_reset = _builder.build()
