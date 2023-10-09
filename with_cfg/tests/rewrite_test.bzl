load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//with_cfg/private:rewrite.bzl", "rewrite_locations_in_attr")

def _mock_rewriter(label):
    return label + "_rewritten"

def _rewrite_locations_in_attr_test(env):
    expect = env.expect
    rewrite = lambda v: rewrite_locations_in_attr(v, _mock_rewriter)

    expect.that_str(
        rewrite("@foo//:baz $(location :foo) :bar"),
    ).equals(
        "@foo//:baz $(location :foo_rewritten) :bar",
    )
    expect.that_str(
        rewrite("$$$$$(rlocationpath @foo//:baz)$$$(execpath :foo)$$"),
    ).equals(
        "$$$$$(rlocationpath @foo//:baz_rewritten)$$$(execpath :foo_rewritten)$$",
    )
    expect.that_str(
        rewrite("$$$$(rlocationpath @foo//:baz)$$$(execpath :foo)$$"),
    ).equals(
        "$$$$(rlocationpath @foo//:baz)$$$(execpath :foo_rewritten)$$",
    )
    expect.that_str(
        rewrite("$(JAVA_HOME)"),
    ).equals(
        "$(JAVA_HOME)",
    )
    expect.that_collection(
        rewrite(["@foo//:baz", "$(location :foo)", ":bar"]),
    ).contains_exactly(
        ["@foo//:baz", "$(location :foo_rewritten)", ":bar"],
    ).in_order()
    expect.that_dict(
        rewrite({"@foo//:baz": "$(rlocationpath :baz)", "bar": "$(location :foo)"}),
    ).contains_exactly(
        {"@foo//:baz": "$(rlocationpath :baz_rewritten)", "bar": "$(location :foo_rewritten)"},
    )
    expect.that_dict(
        rewrite({"@foo//:baz": ["$(rlocationpath :baz)", "bar", "$(location :foo)"]}),
    ).contains_exactly(
        {"@foo//:baz": ["$(rlocationpath :baz_rewritten)", "bar", "$(location :foo_rewritten)"]},
    )

def rewrite_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _rewrite_locations_in_attr_test,
        ],
    )
