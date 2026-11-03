load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//with_cfg/private:select.bzl", "decompose_select_elements")
load("//with_cfg/private:setting.bzl", "clone_setting_value", "get_attr_type", "validate_and_get_attr_name")

_GET_ATTR_TYPE_TEST_CASES = [
    (None, "string_list"),
    ([], "string_list"),
    (select({"//conditions:default": None}), "string_list"),
    (select({"//conditions:default": []}), "string_list"),
    (True, "bool"),
    (select({"//conditions:default": True}), "bool"),
    (select({Label("//conditions:default"): True}), "bool"),
    (False, "bool"),
    (select({"//conditions:default": False}), "bool"),
    (select({Label("//conditions:default"): False}), "bool"),
    (1234, "int"),
    (select({"//conditions:default": 65}), "int"),
    (select({Label("//conditions:default"): 5678}), "int"),
    (-1234, "int"),
    (select({"//conditions:default": -65}), "int"),
    (select({Label("//conditions:default"): -5678}), "int"),
    ([-1234, 5], "int_list"),
    (select({"//conditions:default": [65, 7]}), "int_list"),
    (select({Label("//conditions:default"): [-5678, 8]}), "int_list"),
    ([5] + select({"//conditions:default": [65, 7]}), "int_list"),
    ("foo", "string"),
    (select({"//conditions:default": "foo\"bar"}), "string"),
    (select({Label("//conditions:default"): "foo\"bar"}), "string"),
    ("foo" + select({"//conditions:default": "foo\"bar"}), "string"),
    (["foo", "bar"], "string_list"),
    (select({"//conditions:default": ["foo\"bar"]}), "string_list"),
    (select({Label("//conditions:default"): ["foo\"bar"]}), "string_list"),
    (["foo"] + select({"//conditions:default": ["foo\"bar"]}), "string_list"),
    (Label("//:foo"), "label"),
    (select({"//conditions:default": Label("foo\"bar")}), "label"),
    (select({Label("//conditions:default"): Label("foo\"bar")}), "label"),
    ([Label("//:foo"), Label("//:bar")], "label_list"),
    (select({"//conditions:default": [Label("//:foo"), Label("//:bar")]}), "label_list"),
    (select({Label("//conditions:default"): [Label("//:foo"), Label("//:bar")]}), "label_list"),
    ([Label("//:foo"), Label("//:bar")], "label_list"),
    (select({"//conditions:default": [Label("//:foo"), Label("//:bar")]}), "label_list"),
    ([Label("//:baz")] + select({Label("//conditions:default"): [Label("//:foo"), Label("//:bar")]}), "label_list"),
    # Classify the first nonempty value without rebuilding the selector.
    ([] + ([] + select({"//conditions:default": [Label("//:foo")]})), "label_list"),
    (select({"@rules_cc//cc/compiler:msvc-cl": [1], "//conditions:default": [None]}), "int_list"),
    # Empty lists in selects.
    (select({"@rules_cc//cc/compiler:msvc-cl": [], "//conditions:default": ["-fsanitize=address"]}), "string_list"),
    (select({"@rules_cc//cc/compiler:msvc-cl": [], "//conditions:default": [Label("//:foo")]}), "label_list"),
    (select({"@rules_cc//cc/compiler:msvc-cl": [], "//conditions:default": []}) + [Label("//:foo")], "label_list"),
    (select({"@rules_cc//cc/compiler:msvc-cl": []}) + ["foo"], "string_list"),
]

_VALIDATE_ATTR_NAME_TEST_CASES = [
    # Setting, Name is a valid identifier, Hash is a valid identifier
    (Label("//:foo"), True, False),
    (Label("//:foobar"), True, True),
    (Label("//:foo-bar"), False, False),
    (Label("//:!foo^&bar"), False, True),
    (Label("//:-{abc}"), False, False),
]

def _is_valid_identifier(identifier):
    for c in identifier.elems():
        if not c.isalnum() and c != "_":
            return False
    return True

def _get_attr_type_test(env):
    for value, expected_type in _GET_ATTR_TYPE_TEST_CASES:
        env.expect.where(value = value).that_str(get_attr_type(value)).equals(expected_type)

def _get_attr_name_test(env):
    env.expect.that_str(validate_and_get_attr_name("platforms")).contains("platforms")

    some_setting_subject = env.expect.that_str(validate_and_get_attr_name(Label("@bazel_tools//:some_setting")))
    some_setting_subject.contains("some_setting")
    some_setting_subject.not_equals(validate_and_get_attr_name(Label("@bazel_tools//pkg:some_setting")))

def _validate_attr_name_test(env):
    for value, name_is_valid, hash_is_valid in _VALIDATE_ATTR_NAME_TEST_CASES:
        env.expect.that_bool(_is_valid_identifier(value.name)).equals(name_is_valid)
        env.expect.that_bool(_is_valid_identifier(str(hash(str(value))))).equals(hash_is_valid)
        env.expect.that_bool(_is_valid_identifier(validate_and_get_attr_name(value))).equals(True)

def _clone_setting_value_test(env):
    for value in [[], ["original"]]:
        expected = list(value)
        cloned = clone_setting_value(value)
        env.expect.that_collection(cloned).contains_exactly(expected).in_order()
        cloned.append("changed")
        env.expect.that_collection(value).contains_exactly(expected).in_order()

    nested = []
    plain_tuple = (nested,)
    cloned = clone_setting_value(plain_tuple)
    cloned[0].append("shared")
    env.expect.that_str(type(cloned)).equals("tuple")
    env.expect.that_collection(nested).contains_exactly(["shared"])

    plain_dict = {}
    clone_setting_value(plain_dict)["shared"] = True
    env.expect.that_dict(plain_dict).contains_exactly({"shared": True})

    prefix = ["prefix"]
    branch = ["selected"]
    suffix = ["suffix"]
    selected = prefix + select({"//conditions:default": branch}) + suffix
    cloned = clone_setting_value(selected)
    prefix.append("changed")
    branch.append("changed")
    suffix.append("changed")
    env.expect.that_collection(decompose_select_elements(cloned)).contains_exactly([
        (False, ["prefix"]),
        (True, {"//conditions:default": ["selected"]}),
        (False, ["suffix"]),
    ]).in_order()

    nullable = None + select({"//conditions:default": None}) + None
    env.expect.that_str(repr(clone_setting_value(nullable))).equals(repr(nullable))

def setting_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _clone_setting_value_test,
            _get_attr_name_test,
            _get_attr_type_test,
            _validate_attr_name_test,
        ],
    )
