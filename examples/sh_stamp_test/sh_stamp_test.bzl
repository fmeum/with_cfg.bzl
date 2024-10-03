load("@with_cfg.bzl", "with_cfg")

sh_stamp_test, _unused = with_cfg(native.sh_test).set("stamp", True).build()
