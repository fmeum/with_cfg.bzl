load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_java//java:java_binary.bzl", "java_binary")
load("@rules_java//java:java_library.bzl", "java_library")
load("@rules_java//java:java_test.bzl", "java_test")
load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_library.bzl", "sh_library")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:unit_test.bzl", "unit_test")
load("@rules_testing//lib:util.bzl", "testing_aspect")
load("//:with_cfg.bzl", "with_cfg")
load("//with_cfg/private:with_cfg.bzl", "get_extension_parent", "get_rule_name", "is_executable", "is_test")
load("//with_cfg/private:wrapper.bzl", "make_wrapper")

_filegroup, _filegroup_reset = with_cfg(native.filegroup).resettable(Label(":original_settings")).build()
_executable_filegroup, _executable_filegroup_alias = with_cfg(native.filegroup, executable = True).build()

def _noop_impl(ctx):
    pass

my_binary = rule(_noop_impl, executable = True)
my_library = rule(_noop_impl)
my_test = rule(_noop_impl, test = True)

# A rule stored in a list is not exported as a global rule.
_unexported_rule = [rule(_noop_impl)]
_symbolic_macro = bazel_features.globals.macro(
    implementation = lambda name, visibility: None,
) if bazel_features.globals.macro else None

_string_data = rule(
    _noop_impl,
    attrs = {
        "args": attr.string_list(),
        "data": attr.string_list(),
        "srcs": attr.label_list(allow_files = True),
    },
)

def _string_data_macro(name, **kwargs):
    _string_data(name = name, **kwargs)

_wrapped_string_data, _string_data_alias = with_cfg(_string_data_macro).build()

def _args_non_dependency_test(name):
    subject = name + "_subject"
    _wrapped_string_data(
        name = subject,
        args = ["$(location :BUILD.bazel)"],
        data = ["not a target"],
        srcs = ["BUILD.bazel"],
    )
    analysis_test(name = name, target = subject, impl = _args_non_dependency_test_impl)

def _args_non_dependency_test_impl(env, target):
    env.expect.that_depset_of_files(target[DefaultInfo].files).contains_exactly([])

def _forwarded_tags_test(name):
    frontend_tags = {}
    originals = []
    for suffix, tags in [("tuple", ("example",)), ("depset", depset(["example"]))]:
        subject = name + "_" + suffix
        _wrapped_string_data(name = subject, tags = tags)
        frontend_tags[suffix] = list(native.existing_rule(subject)["tags"])
        originals.append(subject + "_/" + subject)
    unit_test(
        name = name,
        impl = _forwarded_tags_test_impl,
        attrs = {
            "frontend_tags": attr.string_list_dict(default = frontend_tags),
            "originals": attr.label_list(default = originals, aspects = [testing_aspect]),
        },
    )

def _forwarded_tags_test_impl(env):
    for kind, tags in env.ctx.attr.frontend_tags.items():
        env.expect.where(kind = kind).that_collection(tags).contains_exactly(["example"])
    for original in env.ctx.attr.originals:
        env.expect.that_target(original).tags().contains_exactly(["example", "manual"])

_int_args = rule(_noop_impl, attrs = {"args": attr.int()})

def _int_args_macro(name, **kwargs):
    _int_args(name = name, **kwargs)

_wrapped_int_args, _int_args_alias = with_cfg(_int_args_macro).build()

def _args_non_list_test(name):
    subject = name + "_subject"
    _wrapped_int_args(name = subject, args = 42)
    analysis_test(name = name, target = subject, impl = _args_non_dependency_test_impl)

def my_macro_binary():
    pass

def my_macro_library():
    pass

def my_macro_test():
    pass

_wrapped_genrule, _genrule_alias = with_cfg(native.genrule).build()

def _default_frontend_exec_properties_test(name):
    subject = name + "_subject"
    _wrapped_genrule(
        name = subject,
        outs = [subject + ".txt"],
        cmd = "touch $@",
        exec_properties = {"pool": "all"},
    )
    analysis_test(
        name = name,
        target = subject,
        impl = _default_frontend_exec_properties_test_impl,
        attrs = {"expected_output": attr.string(default = "with_cfg/tests/" + subject + ".txt")},
    )

def _default_frontend_exec_properties_test_impl(env, target):
    env.expect.that_depset_of_files(target[DefaultInfo].files).contains_exactly([env.ctx.attr.expected_output])

def _missing_executable_test(name):
    subject = name + "_subject"
    _executable_filegroup(name = subject, tags = ["manual"])
    analysis_test(
        name = name,
        target = subject,
        impl = _missing_executable_test_impl,
        expect_failure = True,
    )

def _missing_executable_test_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("Expected exports to provide an executable, got: *"),
    )

def _execution_attrs_test(name):
    unit_test(name = name, impl = _execution_attrs_test_impl)

def _execution_attrs_test_impl(env):
    properties = {"pool": "all", "test.pool": "test", "compile.pool": "compile"}
    filtered = {"pool": "all", "test.pool": "test"}
    constraints = ["@platforms//os:linux"]
    groups = {"test": constraints, "compile": constraints}
    for value, expected, exec_groups in [
        (None, None, None),
        (properties, filtered, groups),
        (
            select({"//conditions:default": None, "//with_cfg/tests:condition": properties}),
            select({"//conditions:default": {}, "//with_cfg/tests:condition": filtered}),
            groups,
        ),
        (
            None + (None + select({"//conditions:default": None, "//with_cfg/tests:condition": properties})) + None,
            {} | ({} | select({"//conditions:default": {}, "//with_cfg/tests:condition": filtered})) | {},
            groups,
        ),
    ]:
        for executable, test in [(False, False), (True, False), (False, True)]:
            calls = []
            capture = lambda **kwargs: calls.append(kwargs)
            wrapper = make_wrapper(
                rule_info = struct(
                    kind = capture,
                    supports_inheritance = False,
                    executable = executable,
                    test = test,
                    native = False,
                    implicit_targets = [],
                ),
                frontend = capture,
                transitioning_alias = capture,
                values = {},
                original_settings_label = None,
                attrs_to_reset = [],
            )
            wrapper(name = "subject", exec_properties = value, exec_group_compatible_with = exec_groups)
            original, alias, frontend = calls
            expect = env.expect.where(value = value, executable = executable, test = test)
            expect.that_str(repr(original["exec_properties"])).equals(repr(value))
            expect.that_dict(original["exec_group_compatible_with"] or {}).contains_exactly(exec_groups or {})
            expect.that_bool("exec_properties" in alias).equals(False)
            expect.that_bool("exec_group_compatible_with" in alias).equals(False)
            expect.that_str(repr(frontend.get("exec_properties"))).equals(repr(expected if executable or test else None))
            expected_groups = {"test": constraints} if exec_groups and (executable or test) else {}
            expect.that_dict(frontend.get("exec_group_compatible_with", {})).contains_exactly(expected_groups)

def _extension_parent_test(name):
    unit_test(name = name, impl = _extension_parent_test_impl)

def _extension_parent_test_impl(env):
    for kind in [my_binary, my_library, my_test]:
        env.expect.that_bool(get_extension_parent(kind) == kind).equals(True)
    for kind in [native.filegroup, my_macro_library, _symbolic_macro, _unexported_rule[0]]:
        env.expect.that_bool(get_extension_parent(kind) == None).equals(True)
    if not bazel_features.cc.rules_support_extension:
        for kind in [cc_binary, cc_test]:
            env.expect.that_bool(get_extension_parent(kind) == None).equals(True)

def _is_executable_test(name):
    unit_test(
        name = name,
        impl = _is_executable_test_impl,
        attrs = {
            "cc_binary": attr.string(default = get_rule_name(cc_binary)),
            "cc_library": attr.string(default = get_rule_name(cc_library)),
            "cc_test": attr.string(default = get_rule_name(cc_test)),
            "java_binary": attr.string(default = get_rule_name(java_binary)),
            "java_library": attr.string(default = get_rule_name(java_library)),
            "java_test": attr.string(default = get_rule_name(java_test)),
            "my_binary": attr.string(default = get_rule_name(my_binary)),
            "my_library": attr.string(default = get_rule_name(my_library)),
            "my_test": attr.string(default = get_rule_name(my_test)),
            "my_macro_binary": attr.string(default = get_rule_name(my_macro_binary)),
            "my_macro_library": attr.string(default = get_rule_name(my_macro_library)),
            "my_macro_test": attr.string(default = get_rule_name(my_macro_test)),
            "py_binary": attr.string(default = get_rule_name(py_binary)),
            "py_library": attr.string(default = get_rule_name(py_library)),
            "py_test": attr.string(default = get_rule_name(py_test)),
            "sh_binary": attr.string(default = get_rule_name(sh_binary)),
            "sh_library": attr.string(default = get_rule_name(sh_library)),
            "sh_test": attr.string(default = get_rule_name(sh_test)),
        },
    )

def _is_executable_test_impl(env):
    env.expect.where(rule = "cc_binary").that_bool(is_executable(env.ctx.attr.cc_binary)).equals(True)
    env.expect.where(rule = "cc_library").that_bool(is_executable(env.ctx.attr.cc_library)).equals(False)
    env.expect.where(rule = "cc_test").that_bool(is_executable(env.ctx.attr.cc_test)).equals(False)
    env.expect.where(rule = "java_binary").that_bool(is_executable(env.ctx.attr.java_binary)).equals(True)
    env.expect.where(rule = "java_library").that_bool(is_executable(env.ctx.attr.java_library)).equals(False)
    env.expect.where(rule = "java_test").that_bool(is_executable(env.ctx.attr.java_test)).equals(False)
    env.expect.where(rule = "my_binary").that_bool(is_executable(env.ctx.attr.my_binary)).equals(True)
    env.expect.where(rule = "my_library").that_bool(is_executable(env.ctx.attr.my_library)).equals(False)
    env.expect.where(rule = "my_test").that_bool(is_executable(env.ctx.attr.my_test)).equals(False)
    env.expect.where(rule = "my_macro_binary").that_bool(is_executable(env.ctx.attr.my_macro_binary)).equals(True)
    env.expect.where(rule = "my_macro_library").that_bool(is_executable(env.ctx.attr.my_macro_library)).equals(False)
    env.expect.where(rule = "my_macro_test").that_bool(is_executable(env.ctx.attr.my_macro_test)).equals(False)
    env.expect.where(rule = "py_binary").that_bool(is_executable(env.ctx.attr.py_binary)).equals(True)
    env.expect.where(rule = "py_library").that_bool(is_executable(env.ctx.attr.py_library)).equals(False)
    env.expect.where(rule = "py_test").that_bool(is_executable(env.ctx.attr.py_test)).equals(False)
    env.expect.where(rule = "sh_binary").that_bool(is_executable(env.ctx.attr.sh_binary)).equals(True)
    env.expect.where(rule = "sh_library").that_bool(is_executable(env.ctx.attr.sh_library)).equals(False)
    env.expect.where(rule = "sh_test").that_bool(is_executable(env.ctx.attr.sh_test)).equals(False)

def _is_test_test(name):
    unit_test(
        name = name,
        impl = _is_test_test_impl,
        attrs = {
            "cc_binary": attr.string(default = get_rule_name(cc_binary)),
            "cc_library": attr.string(default = get_rule_name(cc_library)),
            "cc_test": attr.string(default = get_rule_name(cc_test)),
            "java_binary": attr.string(default = get_rule_name(java_binary)),
            "java_library": attr.string(default = get_rule_name(java_library)),
            "java_test": attr.string(default = get_rule_name(java_test)),
            "my_binary": attr.string(default = get_rule_name(my_binary)),
            "my_library": attr.string(default = get_rule_name(my_library)),
            "my_test": attr.string(default = get_rule_name(my_test)),
            "my_macro_binary": attr.string(default = get_rule_name(my_macro_binary)),
            "my_macro_library": attr.string(default = get_rule_name(my_macro_library)),
            "my_macro_test": attr.string(default = get_rule_name(my_macro_test)),
            "py_binary": attr.string(default = get_rule_name(py_binary)),
            "py_library": attr.string(default = get_rule_name(py_library)),
            "py_test": attr.string(default = get_rule_name(py_test)),
            "sh_binary": attr.string(default = get_rule_name(sh_binary)),
            "sh_library": attr.string(default = get_rule_name(sh_library)),
            "sh_test": attr.string(default = get_rule_name(sh_test)),
        },
    )

def _is_test_test_impl(env):
    env.expect.where(rule = "cc_binary").that_bool(is_test(env.ctx.attr.cc_binary)).equals(False)
    env.expect.where(rule = "cc_library").that_bool(is_test(env.ctx.attr.cc_library)).equals(False)
    env.expect.where(rule = "cc_test").that_bool(is_test(env.ctx.attr.cc_test)).equals(True)
    env.expect.where(rule = "java_binary").that_bool(is_test(env.ctx.attr.java_binary)).equals(False)
    env.expect.where(rule = "java_library").that_bool(is_test(env.ctx.attr.java_library)).equals(False)
    env.expect.where(rule = "java_test").that_bool(is_test(env.ctx.attr.java_test)).equals(True)
    env.expect.where(rule = "my_binary").that_bool(is_test(env.ctx.attr.my_binary)).equals(False)
    env.expect.where(rule = "my_library").that_bool(is_test(env.ctx.attr.my_library)).equals(False)
    env.expect.where(rule = "my_test").that_bool(is_test(env.ctx.attr.my_test)).equals(True)
    env.expect.where(rule = "my_macro_binary").that_bool(is_test(env.ctx.attr.my_macro_binary)).equals(False)
    env.expect.where(rule = "my_macro_library").that_bool(is_test(env.ctx.attr.my_macro_library)).equals(False)
    env.expect.where(rule = "my_macro_test").that_bool(is_test(env.ctx.attr.my_macro_test)).equals(True)
    env.expect.where(rule = "py_binary").that_bool(is_test(env.ctx.attr.py_binary)).equals(False)
    env.expect.where(rule = "py_library").that_bool(is_test(env.ctx.attr.py_library)).equals(False)
    env.expect.where(rule = "py_test").that_bool(is_test(env.ctx.attr.py_test)).equals(True)
    env.expect.where(rule = "sh_binary").that_bool(is_test(env.ctx.attr.sh_binary)).equals(False)
    env.expect.where(rule = "sh_library").that_bool(is_test(env.ctx.attr.sh_library)).equals(False)
    env.expect.where(rule = "sh_test").that_bool(is_test(env.ctx.attr.sh_test)).equals(True)

def _reset_files_test(name):
    native.filegroup(name = name + "_files", srcs = ["rule_test.bzl"])
    _filegroup_reset(name = name + "_source", exports = "rule_test.bzl")
    _filegroup_reset(name = name + "_rule", exports = name + "_files")
    native.config_setting(name = name + "_config", values = {"compilation_mode": "dbg"})
    _filegroup_reset(name = name + "_empty", exports = name + "_config")
    unit_test(
        name = name,
        impl = _reset_files_test_impl,
        attrs = {
            "resets": attr.label_list(default = [name + "_source", name + "_rule"]),
            "empty_reset": attr.label(default = name + "_empty"),
        },
    )

def _reset_files_test_impl(env):
    for target in env.ctx.attr.resets:
        env.expect.where(target = target.label).that_depset_of_files(target[DefaultInfo].files).contains_exactly([
            "with_cfg/tests/rule_test.bzl",
        ])
        env.expect.where(target = target.label).that_bool(target[DefaultInfo].files_to_run.executable == None).equals(True)
    env.expect.that_depset_of_files(env.ctx.attr.empty_reset[DefaultInfo].files).contains_exactly([])

def rule_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _args_non_dependency_test,
            _args_non_list_test,
            _default_frontend_exec_properties_test,
            _execution_attrs_test,
            _extension_parent_test,
            _forwarded_tags_test,
            _is_executable_test,
            _is_test_test,
            _missing_executable_test,
            _reset_files_test,
        ],
    )
