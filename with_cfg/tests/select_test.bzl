load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load(
    "//with_cfg/private:select.bzl",
    "consume_list",
    "consume_single_value",
    "decompose_select_elements",
    "map_attr",
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

def _map_nullable_select_test(env):
    value = None + (None + select({"//conditions:default": None})) + None + None
    mapped = map_attr(lambda value: value, value)
    env.expect.that_collection(decompose_select_elements(mapped)).contains_exactly([
        (False, None),
        (False, None),
        (True, {"//conditions:default": None}),
        (False, None),
        (False, None),
    ]).in_order()

def _map_select_order_test(env):
    values = ["first"] + (["second"] + select({"//conditions:default": ["selected"]})) + ["last"]
    mapped = map_attr(lambda values: [value.upper() for value in values], values)
    env.expect.that_collection([
        value
        for in_select, element in decompose_select_elements(mapped)
        for value in (element["//conditions:default"] if in_select else element)
    ]).contains_exactly(["FIRST", "SECOND", "SELECTED", "LAST"]).in_order()

    value = "first" + ("second" + select({"//conditions:default": "selected"})) + "last"
    mapped = map_attr(lambda value: value.upper(), value)
    env.expect.that_str("".join([
        element["//conditions:default"] if in_select else element
        for in_select, element in decompose_select_elements(mapped)
    ])).equals("FIRSTSECONDSELECTEDLAST")

def _map_select_dict_test(env):
    first = {"first": "one", "prefix": "first", "shared": "first"}
    second = {"second": "two", "prefix": "second", "shared": "second"}
    selected = select({"//conditions:default": {"selected": "three", "shared": "selected"}})
    last = {"last": "four", "shared": "last"}
    value = first | (second | selected) | last
    mapped = map_attr(lambda value: {key: item.upper() for key, item in value.items()}, value)
    env.expect.that_dict(dict([
        pair
        for in_select, element in decompose_select_elements(mapped)
        for pair in (element["//conditions:default"] if in_select else element).items()
    ])).contains_exactly({"first": "ONE", "second": "TWO", "prefix": "SECOND", "selected": "THREE", "last": "FOUR", "shared": "LAST"})

_SelectedValueInfo = provider(fields = ["values"])

def _selected_value_impl(ctx):
    return [_SelectedValueInfo(values = ctx.attr.values)]

_selected_dict = rule(
    implementation = _selected_value_impl,
    attrs = {"values": attr.string_dict()},
)

_selected_string_list = rule(
    implementation = _selected_value_impl,
    attrs = {"values": attr.string_list()},
)

def _map_list_attribute_test(name):
    subject = name + "_subject"
    value = select({"//conditions:default": "selected"}) + "suffix"
    _selected_string_list(
        name = subject,
        values = map_attr(lambda value: ["a"] if value == "selected" else ["b"], value),
    )
    analysis_test(
        name = name,
        target = subject,
        impl = _map_list_attribute_test_impl,
    )

def _map_list_attribute_test_impl(env, target):
    env.expect.that_collection(target[_SelectedValueInfo].values).contains_exactly(["a", "b"]).in_order()

def _none_first_dict_attribute_test(name):
    dict_condition = name + "_dict"
    native.config_setting(
        name = dict_condition,
        values = {"compilation_mode": "opt"},
    )
    subject = name + "_subject"
    value = select({
        "//conditions:default": None,
        ":" + dict_condition: {"first": "one"},
    }) + select({
        "//conditions:default": None,
        ":" + dict_condition: {"second": "two"},
    })
    _selected_dict(
        name = subject,
        values = map_attr(lambda value: value, value),
    )
    analysis_test(
        name = name,
        target = subject,
        impl = _none_first_dict_attribute_test_impl,
        config_settings = {"//command_line_option:compilation_mode": "opt"},
    )

def _none_first_dict_attribute_test_impl(env, target):
    env.expect.that_dict(target[_SelectedValueInfo].values).contains_exactly({
        "first": "one",
        "second": "two",
    })

def _map_none_first_dict_test(env):
    first = {":first": None, "//conditions:default": {"first": "one"}}
    second = {":second": None, "//conditions:default": {"second": "two"}}
    value = select(first) + select(second)
    mapped = map_attr(lambda value: value, value)
    env.expect.that_collection(decompose_select_elements(mapped)).contains_exactly([
        (True, first),
        (True, second),
    ]).in_order()

    mapped = map_attr(lambda value: {} if value == None else value, value)
    env.expect.that_collection(decompose_select_elements(mapped)).contains_exactly([
        (True, {":first": {}, "//conditions:default": {"first": "one"}}),
        (True, {":second": {}, "//conditions:default": {"second": "two"}}),
    ]).in_order()

def select_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _map_list_attribute_test,
            _none_first_dict_attribute_test,
        ],
        basic_tests = [
            _consume_list_test,
            _consume_single_value_test,
            _decompose_select_value_test,
            _map_nullable_select_test,
            _map_select_order_test,
            _map_select_dict_test,
            _map_none_first_dict_test,
        ],
    )
