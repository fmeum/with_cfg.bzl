load("@rules_java//java:java_binary.bzl", "java_binary")
load("@rules_java//java:java_library.bzl", "java_library")
load("@rules_java//java:java_test.bzl", "java_test")
load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_library.bzl", "sh_library")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("@rules_testing//lib:unit_test.bzl", "unit_test")
load("//with_cfg/private:with_cfg.bzl", "get_rule_name", "is_executable", "is_test")

def _noop_impl(ctx):
    pass

my_binary = rule(_noop_impl, executable = True)
my_library = rule(_noop_impl)
my_test = rule(_noop_impl, test = True)

def my_macro_binary():
    pass

def my_macro_library():
    pass

def my_macro_test():
    pass

def _is_executable_test(name):
    unit_test(
        name = name,
        impl = _is_executable_test_impl,
        attrs = {
            "cc_binary": attr.string(default = get_rule_name(native.cc_binary)),
            "cc_library": attr.string(default = get_rule_name(native.cc_library)),
            "cc_test": attr.string(default = get_rule_name(native.cc_test)),
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
            "cc_binary": attr.string(default = get_rule_name(native.cc_binary)),
            "cc_library": attr.string(default = get_rule_name(native.cc_library)),
            "cc_test": attr.string(default = get_rule_name(native.cc_test)),
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

def rule_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _is_executable_test,
            _is_test_test,
        ],
    )
