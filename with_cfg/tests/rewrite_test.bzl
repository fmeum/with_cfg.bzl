load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//with_cfg/private:rewrite.bzl", "rewrite_dependency_attrs", "rewrite_dependency_labels", "rewrite_locations_in_attr", "rewrite_locations_in_string_dict", "rewrite_locations_in_string_list")

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

def _dependency_rewrites():
    calls = []
    label_map = {}

    def reset_target(*, name, exports):
        calls.append((name, exports))
        return "ignored"

    def rewrite(value, prefix = "deps"):
        return rewrite_dependency_labels(
            value,
            label_map = label_map,
            reset_target = reset_target,
            name = prefix,
        )

    dep_a = native.package_relative_label(":a")
    dep_b = native.package_relative_label(":b")
    dep_c = native.package_relative_label(":c")
    original = [":a", dep_b]
    rewritten = rewrite(original + select({"//conditions:default": [dep_b, ":c"], ":other": [":a"]}) + [":c"])
    expected = [":deps_0", native.package_relative_label(":deps_1")] + select({"//conditions:default": [native.package_relative_label(":deps_1"), ":deps_2"], ":other": [":deps_0"]}) + [":deps_2"]

    initial_calls = list(calls)

    # A later attribute shares replacements, but names its first new target from zero.
    other = rewrite([":a", ":d"], "other")
    after_other_calls = list(calls)

    # Only dictionary keys are dependencies; values and their aliases are retained.
    shared = []
    dictionary = rewrite({":a": shared, ":b": "unchanged"})
    dictionary[":deps_0"].append("shared")
    selected = select({"//conditions:default": None, ":other": {dep_a: "$(location :a)"}})
    expected_selected = select({"//conditions:default": None, ":other": {native.package_relative_label(":deps_0"): "$(location :a)"}})

    return struct(
        original = original,
        rewritten = rewritten,
        expected = expected,
        initial_calls = initial_calls,
        other = other,
        after_other_calls = after_other_calls,
        dictionary = dictionary,
        shared = shared,
        nullable = rewrite(None + selected + None),
        expected_nullable = None + expected_selected + None,
        plain_none = rewrite(None),
        empty = rewrite([]),
        string = rewrite(":a"),
        label = rewrite(dep_b),
        expected_label = native.package_relative_label(":deps_1"),
        dep_a = dep_a,
        dep_b = dep_b,
        dep_c = dep_c,
        dep_d = native.package_relative_label(":d"),
    )

def _check_dependency_rewrites(env, result):
    env.expect.that_str(repr(result.rewritten)).equals(repr(result.expected))
    env.expect.that_collection(result.original).contains_exactly([":a", result.dep_b]).in_order()
    env.expect.that_collection(result.initial_calls).contains_exactly([("deps_0", result.dep_a), ("deps_1", result.dep_b), ("deps_2", result.dep_c)]).in_order()
    env.expect.that_collection(result.other).contains_exactly([":deps_0", ":other_0"]).in_order()
    env.expect.that_collection(result.after_other_calls).contains_exactly([("deps_0", result.dep_a), ("deps_1", result.dep_b), ("deps_2", result.dep_c), ("other_0", result.dep_d)]).in_order()
    env.expect.that_collection(result.shared).contains_exactly(["shared"])
    env.expect.that_dict(result.dictionary).contains_exactly({":deps_0": ["shared"], ":deps_1": "unchanged"})
    env.expect.that_str(repr(result.nullable)).equals(repr(result.expected_nullable))
    env.expect.that_str(repr(result.plain_none)).equals("None")
    env.expect.that_collection(result.empty).contains_exactly([])
    env.expect.that_str(result.string).equals(":deps_0")
    env.expect.that_str(str(result.label)).equals(str(result.expected_label))

def _dependency_attr_rewrites():
    calls = []

    def reset_target(*, name, exports):
        calls.append((name, exports))

    attrs = {
        "deps": [":a"] + select({"//conditions:default": [":b"], ":other": [":a"]}),
        "tools": {":a": "$(location :b)", ":c": "$(location :a)"},
        "cmd": "$(location :c) $(location :b)",
    }
    original = repr(attrs)
    rewritten = rewrite_dependency_attrs(
        attrs = attrs,
        attrs_to_reset = ["missing", "deps", "tools"],
        reset_target = reset_target,
        name = "target",
    )
    unchanged = {"value": "before"}
    alias = rewrite_dependency_attrs(attrs = unchanged, attrs_to_reset = [], reset_target = reset_target, name = "unused")
    alias["value"] = "after"
    return struct(
        attrs = attrs,
        original = original,
        rewritten = rewritten,
        calls = calls,
        unchanged = unchanged,
        expected_calls = [
            ("target__deps_0", native.package_relative_label(":a")),
            ("target__deps_1", native.package_relative_label(":b")),
            ("target__tools_0", native.package_relative_label(":c")),
        ],
        expected_deps = [":target__deps_0"] + select({"//conditions:default": [":target__deps_1"], ":other": [":target__deps_0"]}),
    )

def _check_dependency_attr_rewrites(env, result):
    env.expect.that_str(repr(result.attrs)).equals(result.original)
    env.expect.that_collection(result.calls).contains_exactly(result.expected_calls).in_order()
    env.expect.that_collection(result.rewritten.keys()).contains_exactly(["deps", "tools", "cmd"]).in_order()
    env.expect.that_str(repr(result.rewritten["deps"])).equals(repr(result.expected_deps))
    env.expect.that_dict(result.rewritten["tools"]).contains_exactly({
        ":target__deps_0": "$(location :target__deps_1)",
        ":target__tools_0": "$(location :target__deps_0)",
    })
    env.expect.that_str(result.rewritten["cmd"]).equals("$(location :target__tools_0) $(location :target__deps_1)")
    env.expect.that_dict(result.unchanged).contains_exactly({"value": "after"})

def rewrite_test_suite(name):
    dependency_rewrites = _dependency_rewrites()
    dependency_attr_rewrites = _dependency_attr_rewrites()

    def _rewrite_dependency_labels_test(env):
        _check_dependency_rewrites(env, dependency_rewrites)

    def _rewrite_dependency_attrs_test(env):
        _check_dependency_attr_rewrites(env, dependency_attr_rewrites)

    test_suite(
        name = name,
        basic_tests = [
            _rewrite_dependency_attrs_test,
            _rewrite_dependency_labels_test,
            _rewrite_parsed_select_test,
            _rewrite_locations_in_attr_test,
            _rewrite_string_list_dictionary_test,
        ],
    )
