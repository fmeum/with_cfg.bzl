load("@with_cfg.bzl", "with_cfg")

_first_builder = with_cfg(native.cc_test)
_first_builder.set(
    "cxxopt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DCXX_VALUE=\"first\""],
        "//conditions:default": ["-DCXX_VALUE=\"first\""],
    }),
)
_first_builder_copt_msvc = ["/DC_VALUE=\"first\""]
_first_builder_copt_default = ["-DC_VALUE=\"first\""]
_first_builder.extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): _first_builder_copt_msvc,
        "//conditions:default": _first_builder_copt_default,
    }),
)
first_cc_test, _first_cc_test_ = _first_builder.build()

second_builder = _first_builder.clone()

# Demonstrate that clone() does not share mutable state with the original builder.
_first_builder_copt_default[0] = "-DC_VALUE=\"unexpected\""
second_builder.set(
    "cxxopt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DCXX_VALUE=\"second\""],
        "//conditions:default": ["-DCXX_VALUE=\"second\""],
    }),
)
second_cc_test, _second_cc_test_ = second_builder.build()
