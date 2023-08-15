load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_test)
_builder.extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DNAME=\"with_cfg\""],
        "//conditions:default": ["-DNAME=\"with_cfg\""],
    }),
)
cc_define_test, _cc_define_test_ = _builder.build()
