load("@with_cfg.bzl", "with_cfg")

opt_filegroup, opt_filegroup_reset = with_cfg(native.filegroup).set("compilation_mode", "opt").resettable(Label(":opt_filegroup_original_settings")).build()
