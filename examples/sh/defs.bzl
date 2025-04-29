load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@with_cfg.bzl", "with_cfg")

my_sh_test, _my_sh_test_ = with_cfg(sh_test).build()
