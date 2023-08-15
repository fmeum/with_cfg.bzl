load("@with_cfg.bzl", "with_cfg")

cc_asan_test, cc_asan_test_reset = with_cfg(
    native.cc_test,
).extend(
    "copt",
    ["-fsanitize=address"],
).extend(
    "linkopt",
    select({
        # link.exe doesn't require or recognize -fsanitize=address and would emit a warning.
        "@rules_cc//cc/compiler:msvc-cl": [],
        "//conditions:default": ["-fsanitize=address"],
    }),
).resettable(
    Label(":cc_asan_test_original_settings"),
).build()
