load("@with_cfg.bzl", "with_cfg")

my_sh_test, _my_sh_test_ = with_cfg(native.sh_test).build()
