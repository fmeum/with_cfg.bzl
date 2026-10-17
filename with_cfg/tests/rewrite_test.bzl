load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//with_cfg/private:rewrite.bzl", "rewrite_locations_in_attr", "rewrite_locations_in_string_dict", "rewrite_locations_in_string_list")

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

def _rewrite_string_list_dictionary_test(env):
    calls = []

    def rewrite_label(label):
        calls.append(label)
        return ":same"

    value = {
        "$(location :first)": ["$(location :value_one)", "$(location :value_two)"],
        "middle": "$(location :scalar)",
        "$(location :last)": "$(location :value_three)",
    }
    rewritten = rewrite_locations_in_string_dict(value, rewrite_label)
    env.expect.that_dict(rewritten).contains_exactly({"$(location :same)": "$(location :same)", "middle": "$(location :same)"})
    env.expect.that_collection(rewritten.keys()).contains_exactly(["$(location :same)", "middle"]).in_order()
    env.expect.that_collection(calls).contains_exactly([
        ":first",
        ":value_one",
        ":value_two",
        ":scalar",
        ":last",
        ":value_three",
    ]).in_order()

    calls.clear()
    result = rewrite_locations_in_string_list(value, rewrite_label)
    env.expect.that_collection(result).contains_exactly(rewritten.keys()).in_order()

def _rewrite_parsed_select_test(env):
    cases = [
        ("$(location :prefix)" + select({"//conditions:default": "$(location :selected)"}) + "$(location :suffix)", "$(location :prefix_rewritten)" + select({"//conditions:default": "$(location :selected_rewritten)"}) + "$(location :suffix_rewritten)"),
        (["$(location :prefix)"] + select({"//conditions:default": ["$(location :selected)"]}) + ["$(location :suffix)"], ["$(location :prefix_rewritten)"] + select({"//conditions:default": ["$(location :selected_rewritten)"]}) + ["$(location :suffix_rewritten)"]),
        ({"$(location :key)": "$(location :value)"} | select({"//conditions:default": {"selected": ["$(location :selected)"]}}), {"$(location :key_rewritten)": "$(location :value_rewritten)"} | select({"//conditions:default": {"selected": ["$(location :selected_rewritten)"]}})),
        (None + select({"//conditions:default": None, ":other": {"$(location :key)": "$(location :value)"}}) + None, None + select({"//conditions:default": None, ":other": {"$(location :key_rewritten)": "$(location :value_rewritten)"}}) + None),
        (select({"//conditions:default": Label("//:value")}), select({"//conditions:default": Label("//:value")})),
        (select({"//conditions:default": 42}), select({"//conditions:default": 42})),
        (Label("//:prefix") + select({"//conditions:default": Label("//:selected")}) + Label("//:suffix"), Label("//:prefix") + select({"//conditions:default": Label("//:selected")}) + Label("//:suffix")),
        (1 + select({"//conditions:default": 2}) + 3, 1 + select({"//conditions:default": 2}) + 3),
    ]
    for value, expected in cases:
        env.expect.that_str(repr(rewrite_locations_in_attr(value, _mock_rewriter))).equals(repr(expected))

    calls = []

    def recording_rewriter(label):
        calls.append(label)
        return label + "_rewritten"

    rewrite_locations_in_attr({"$(location :prefix_key)": "$(location :prefix_value)"} | select({"//conditions:default": {"$(location :selected_key)": ["$(location :selected_value)"]}, ":other": {"$(location :other_key)": "$(location :other_value)"}}) | {"$(location :suffix_key)": "$(location :suffix_value)"}, recording_rewriter)
    env.expect.that_collection(calls).contains_exactly([":prefix_key", ":prefix_value", ":selected_key", ":selected_value", ":other_key", ":other_value", ":suffix_key", ":suffix_value"]).in_order()

def rewrite_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _rewrite_parsed_select_test,
            _rewrite_locations_in_attr_test,
            _rewrite_string_list_dictionary_test,
        ],
    )
