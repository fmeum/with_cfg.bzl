load("@with_cfg.bzl", "with_cfg")

cc_asan_test, _cc_asan_test_internal = with_cfg(
    native.cc_test,
).extend(
    "copt",
    select({
        "@rules_cc//cc/compiler:msvc-cl": ["/fsanitize=address"],
        "//conditions:default": ["-fsanitize=address"],
    }),
).extend(
    "linkopt",
    select({
        "@rules_cc//cc/compiler:msvc-cl": [],
        "//conditions:default": ["-fsanitize=address"],
    }),
).build()
