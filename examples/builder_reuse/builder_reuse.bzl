load(":builder.bzl", "second_builder")

_third_builder = second_builder.clone()
_third_builder.extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DC_VALUE=\"third\""],
        "//conditions:default": ["-DC_VALUE=\"third\""],
    }),
)
third_cc_test, _third_cc_test_ = _third_builder.build()
