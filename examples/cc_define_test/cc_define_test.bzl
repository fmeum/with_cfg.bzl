load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_test)
_builder.extend(
    "copt",
    select({
        Label("@rules_cc//cc/compiler:msvc-cl"): ["/DNAME=\"with_cfg\""],
        "//conditions:default": ["-DNAME=\"with_cfg\""],
    }),
)
_builder.reset_on_attrs(
    "data",
    "srcs",
    # Verify that an unspecified reset attr doesn't result in an error.
    "additional_linker_inputs",
)
_builder.resettable(Label(":cc_define_test_original_settings"))
cc_define_test, _cc_define_test_reset = _builder.build()
