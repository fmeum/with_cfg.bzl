load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_test)
_builder.extend("copt", ["-fsanitize=address"])
_builder.extend("linkopt", select({
    # link.exe doesn't require or recognize -fsanitize=address and would emit a warning.
    "@rules_cc//cc/compiler:msvc-cl": [],
    "//conditions:default": ["-fsanitize=address"],
}))
_builder.resettable(Label(":cc_asan_test_original_settings"))
_builder.reset_on_attrs("data", "srcs")
cc_asan_test, cc_asan_test_reset = _builder.build()
