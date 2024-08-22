load("@with_cfg.bzl", "with_cfg")

_first_builder = with_cfg(native.cc_test)
_first_builder.set(
    "cxxopt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DCXX_VALUE=\"first\""],
        "//conditions:default": ["-DCXX_VALUE=\"first\""],
    }),
)
_first_builder.extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DC_VALUE=\"first\""],
        "//conditions:default": ["-DC_VALUE=\"first\""],
    }),
)
first_cc_test, _first_cc_test_ = _first_builder.build()

second_builder = _first_builder
second_builder.set(
    "cxxopt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DCXX_VALUE=\"second\""],
        "//conditions:default": ["-DCXX_VALUE=\"second\""],
    }),
)
second_cc_test, _second_cc_test_ = second_builder.build()
