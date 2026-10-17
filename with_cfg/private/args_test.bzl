load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:unit_test.bzl", "unit_test")
load(":args.bzl", "args_aspect", "rewrite_args")
load(":providers.bzl", "ArgsInfo")
load(":rewrite.bzl", "rewrite_locations_in_attr")

visibility(["//with_cfg/tests"])

def _template_variables_impl(_ctx):
    return [platform_common.TemplateVariableInfo({"CUSTOM": "value"})]

_template_variables = rule(_template_variables_impl)

_ArgsValueInfo = provider(fields = ["args"])

def _subject_impl(ctx):
    return [_ArgsValueInfo(args = ctx.attr.args)]

_subject = rule(_subject_impl, attrs = {"args": attr.string_list()})

def _args_toolchain_test(name):
    _template_variables(name = name + "_variables")
    subject = name + "_subject"
    _subject(name = subject, args = ["$(CUSTOM)"], toolchains = [name + "_variables"])
    unit_test(
        name = name,
        impl = _args_toolchain_test_impl,
        attrs = {"subject": attr.label(default = native.package_relative_label(subject), aspects = [args_aspect])},
    )

def _args_toolchain_test_impl(env):
    variables = env.ctx.attr.subject[ArgsInfo].template_variable_info.variables
    env.expect.that_dict(variables).contains_exactly({"CUSTOM": "value"})

def _rewrite_nullable_args_test(env):
    filegroups = []

    def make_filegroup(*, name, srcs, output_group):
        filegroups.append((name, srcs, output_group))

    rewritten, labels = rewrite_args("plain", None, make_filegroup)
    env.expect.that_bool(rewritten == None).equals(True)
    env.expect.that_collection(labels).contains_exactly([])

    for args in [
        select({"//conditions:default": None}),
        select({"//conditions:default": None, ":condition": ["--flag"]}),
        select({"//conditions:default": ["--flag"], ":condition": None}),
    ]:
        rewritten, labels = rewrite_args("selected", args, make_filegroup)
        env.expect.that_str(repr(rewritten)).equals(repr(args))
        env.expect.that_collection(labels).contains_exactly([])
    env.expect.that_collection(filegroups).contains_exactly([])

def _rewrite_plain_args_test(name):
    filegroups = []

    def make_filegroup(*, name, srcs, output_group):
        filegroups.append((name, srcs, output_group))

    empty = []
    rewritten, empty_labels = rewrite_args("empty", empty, make_filegroup)
    rewritten.append("--flag")
    empty_dict = {}
    rewritten_dict, empty_dict_labels = rewrite_args("empty_dict", empty_dict, make_filegroup)
    rewritten_dict["--flag"] = None
    tuple_args = ("$(location :unchanged)",)
    tuple_result, tuple_labels = rewrite_args("tuple", tuple_args, make_filegroup)
    untouched_filegroups = list(filegroups)

    compatibility = []
    for value in ["$(location :input)", {"key": "$(location :input)"}]:
        compatibility.append(rewrite_args("compat", value, make_filegroup))
    expected_label = native.package_relative_label("compat__args___Cinput")

    def impl(env):
        env.expect.that_collection(empty).contains_exactly(["--flag"])
        env.expect.that_collection(empty_labels).contains_exactly([])
        env.expect.that_dict(empty_dict).contains_exactly({"--flag": None})
        env.expect.that_collection(empty_dict_labels).contains_exactly([])
        env.expect.that_str(repr(tuple_result)).equals(repr(tuple_args))
        env.expect.that_collection(tuple_labels).contains_exactly([])
        env.expect.that_collection(untouched_filegroups).contains_exactly([])
        env.expect.that_collection(compatibility).contains_exactly([
            ("$(location :compat__args___Cinput)", [expected_label]),
            ({"key": "$(location :compat__args___Cinput)"}, [expected_label]),
        ]).in_order()

    unit_test(name = name, impl = impl)

def _rewrite_selected_args_test(name):
    filegroups = []

    def make_filegroup(*, name, srcs, output_group):
        filegroups.append((name, srcs, output_group))

    args = ["$(location :prefix)"] + select({
        "//conditions:default": ["$(location :first)", "$(location :shared)"],
        ":condition": ["$(location :second)"],
    }) + ["$(location :last)", "$(location :shared)"]
    rewritten, labels = rewrite_args("ordered", args, make_filegroup)
    expected = ["$(location :ordered__args___Cprefix)"] + select({
        "//conditions:default": ["$(location :ordered__args___Cfirst)", "$(location :ordered__args___Cshared)"],
        ":condition": ["$(location :ordered__args___Csecond)"],
    }) + ["$(location :ordered__args___Clast)", "$(location :ordered__args___Cshared)"]
    expected_names = ["ordered__args___C" + label for label in ["prefix", "first", "shared", "second", "last"]]
    expected_labels = [native.package_relative_label(label) for label in expected_names]

    def impl(env):
        env.expect.that_str(repr(rewritten)).equals(repr(expected))
        env.expect.that_collection([entry[0] for entry in filegroups]).contains_exactly(expected_names).in_order()
        env.expect.that_collection(labels).contains_exactly(expected_labels).in_order()

    unit_test(name = name, impl = impl)

def _rewrite_dictionary_args_test(name):
    condition = name + "_fastbuild"
    native.config_setting(name = condition, values = {"compilation_mode": "fastbuild"})
    condition = ":" + condition
    cases = [
        (
            {"duplicate": "$(location :prefix_value)"} | select({
                "//conditions:default": {"duplicate": "$(location :selected_value)", "$(location :key)": "$(location :value)"},
            }) | {"duplicate": "$(location :suffix_value)"},
            ["duplicate", "duplicate", "$(location :" + name + "__args___Ckey)", "duplicate"],
        ),
        (
            select({"//conditions:default": {"fallback": None}, condition: ["$(location :list)"]}) | select({
                "//conditions:default": {"fallback": None},
                condition: {"duplicate": "$(location :dict_value)"},
            }),
            ["$(location :" + name + "__args___Clist)", "duplicate"],
        ),
        (
            select({"//conditions:default": None, condition: {"duplicate": ["$(location :nested_value)"]}}) + select({
                "//conditions:default": None,
                condition: ["duplicate"],
            }),
            ["duplicate", "duplicate"],
        ),
        (
            select({"//conditions:default": ["fallback"], condition: {"duplicate": None}}) + select({
                "//conditions:default": ["fallback"],
                condition: None,
            }),
            ["duplicate"],
        ),
        (
            {"$(location :plain_key)": ["$(location :plain_value)", 42], "plain": None},
            ["$(location :" + name + "__args___Cplain_Ukey)", "plain"],
        ),
    ]
    attrs = {}
    expected = []
    old_labels = []
    filegroups = []

    def old_rewriter(label):
        old_labels.append(label)
        return ":" + name + "__args___C" + label[1:].replace("_", "_U")

    def make_filegroup(*, name, srcs, output_group):
        filegroups.append((name, srcs, output_group))

    for i, (value, argv) in enumerate(cases):
        old = rewrite_locations_in_attr(value, old_rewriter)
        rewritten, _labels = rewrite_args(name, value, make_filegroup)
        for side, args in [("old", old), ("new", rewritten)]:
            target = name + "_" + side + str(i)
            _subject(name = target, args = args)
            attrs[side + str(i)] = attr.label(default = native.package_relative_label(target))
        expected.append(argv)

    expected_labels = [
        ":prefix_value",
        ":selected_value",
        ":key",
        ":value",
        ":suffix_value",
        ":list",
        ":dict_value",
        ":nested_value",
        ":plain_key",
        ":plain_value",
    ]
    expected_names = [name + "__args___C" + label[1:].replace("_", "_U") for label in expected_labels]

    fallback_args = [expected[0], ["fallback", "fallback"], [], ["fallback", "fallback"], expected[4]]

    def impl(env):
        configured_args = expected if env.ctx.var["COMPILATION_MODE"] == "fastbuild" else fallback_args
        env.expect.that_collection(old_labels).contains_exactly(expected_labels).in_order()
        for i, argv in enumerate(configured_args):
            old = getattr(env.ctx.attr, "old" + str(i))[_ArgsValueInfo].args
            rewritten = getattr(env.ctx.attr, "new" + str(i))[_ArgsValueInfo].args
            env.expect.that_collection(old).contains_exactly(argv).in_order()
            env.expect.that_collection(rewritten).contains_exactly(argv).in_order()
        env.expect.that_collection([entry[0] for entry in filegroups]).contains_exactly(expected_names).in_order()

    unit_test(name = name, impl = impl, attrs = attrs)

def args_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [_rewrite_nullable_args_test],
        tests = [_args_toolchain_test, _rewrite_plain_args_test, _rewrite_selected_args_test, _rewrite_dictionary_args_test],
    )
