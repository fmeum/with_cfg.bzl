load("@with_cfg//with_cfg:defs.bzl", "with_cfg")

cc_define_test, _cc_define_test_ = with_cfg(native.cc_test).extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DNAME=\"with_cfg\""],
        "//conditions:default": ["-DNAME=\"with_cfg\""],
    }),
).build()
