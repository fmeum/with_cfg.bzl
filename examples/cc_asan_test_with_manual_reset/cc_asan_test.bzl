load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_test)
_builder.extend("copt", ["-fsanitize=address"])
_builder.extend("linkopt", select({
    # link.exe doesn't require or recognize -fsanitize=address and would emit a warning.
    Label("@rules_cc//cc/compiler:msvc-cl"): [],
    "//conditions:default": ["-fsanitize=address"],
}))
_builder.resettable(Label(":cc_asan_test_original_settings"))
cc_asan_test, cc_asan_test_reset = _builder.build()
