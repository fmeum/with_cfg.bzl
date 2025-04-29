load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(cc_binary)
_builder.extend("copt", ["-DGREETING=\"Hello,_world!\""])
cc_define_binary, _cc_define_binary = _builder.build()
