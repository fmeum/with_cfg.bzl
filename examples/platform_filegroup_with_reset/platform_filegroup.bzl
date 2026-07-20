load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.filegroup)
_builder.set("platforms", [Label(":transitioned_platform")])
_builder.resettable(Label(":platform_filegroup_original_settings"))
platform_filegroup, platform_filegroup_reset = _builder.build()
