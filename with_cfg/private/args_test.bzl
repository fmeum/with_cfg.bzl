load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:unit_test.bzl", "unit_test")
load(":args.bzl", "args_aspect")
load(":providers.bzl", "ArgsInfo")

visibility(["//with_cfg/tests"])

def _template_variables_impl(_ctx):
    return [platform_common.TemplateVariableInfo({"CUSTOM": "value"})]

_template_variables = rule(_template_variables_impl)

def _subject_impl(_ctx):
    return []

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

def args_test_suite(name):
    test_suite(name = name, tests = [_args_toolchain_test])
