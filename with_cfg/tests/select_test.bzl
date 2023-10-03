load("@rules_testing//lib:test_suite.bzl", "test_suite")
load(
    "//with_cfg/private:select.bzl",
    "consume_list",
    "consume_single_value",
    "decompose_select_elements",
)

_CONSUME_SINGLE_VALUE_TEST_CASES = [
    None,
    False,
    True,
    "foobar",
    "\"f \0\1\14 oo\"bar\n\t\"",
    Label("//:foobar"),
    -5213213213,
    1012300,
]

def _consume_single_value_test(env):
    for case in _CONSUME_SINGLE_VALUE_TEST_CASES:
        r = repr(case)

        # TODO: rules_testing doesn't accept tuples as collection subjects.
        env.expect.that_collection(
            list(consume_single_value(r, 0)),
        ).contains_exactly(
            [case, len(r)],
        ).in_order()

def _consume_list_test(env):
    r = repr(_CONSUME_SINGLE_VALUE_TEST_CASES)
    env.expect.that_collection(
        list(consume_list(r, 0)),
    ).contains_exactly(
        [_CONSUME_SINGLE_VALUE_TEST_CASES, len(r)],
    ).in_order()

def _decompose_select_value_test(env):
    d = {
        "foo": "bar",
        Label("//foo"): "baz",
        "label_list": [":blub", ":blub", Label("//:baz")],
        "empty_list": [],
        "empty_dict": {},
        "string_list_dict": {
            "foo": [],
            "bar": ["one", "two"],
        },
        "label_keyed_string_dict": {
            Label("//foo"): "bar",
            "//:foo": "baz",
        },
    }
    env.expect.that_collection(
        list(decompose_select_elements(d)),
    ).contains_exactly(
        [(False, d)],
    ).in_order()

def select_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _consume_list_test,
            _consume_single_value_test,
            _decompose_select_value_test,
        ],
    )
