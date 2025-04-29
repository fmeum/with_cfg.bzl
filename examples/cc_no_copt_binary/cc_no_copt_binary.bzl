load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(cc_test)

# Verify that set supports empty lists and None.
_builder.set("copt", [])
_builder.set("host_copt", None)
cc_no_copt_binary, _cc_no_copt_binary = _builder.build()
