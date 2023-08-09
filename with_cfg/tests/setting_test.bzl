load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//with_cfg/private:setting.bzl", "get_attr_type", "validate_and_get_attr_name")

_GET_ATTR_TYPE_TEST_CASES = [
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
]

def _get_attr_type_test(env):
    for value, expected_type in _GET_ATTR_TYPE_TEST_CASES:
        env.expect.where(value = value).that_str(get_attr_type(value)).equals(expected_type)

def _get_attr_name_test(env):
    env.expect.that_str(validate_and_get_attr_name("platforms")).equals("platforms")

    some_setting_subject = env.expect.that_str(validate_and_get_attr_name(Label("@bazel_tools//:some_setting")))
    some_setting_subject.contains("some_setting")
    some_setting_subject.not_equals(validate_and_get_attr_name(Label("@bazel_tools//pkg:some_setting")))

def setting_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _get_attr_name_test,
            _get_attr_type_test,
        ],
    )
