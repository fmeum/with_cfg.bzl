load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_binary)

# Verify that set supports empty lists and None.
_builder.set("copt", [])
_builder.set("host_copt", None)
cc_no_copt_binary, _cc_no_copt_binary = _builder.build()
