load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//:with_cfg.bzl", "with_cfg")

def _legacy_binary(name, **kwargs):
    sh_binary(name = name, **kwargs)

_wrapped_binary, _reset = with_cfg(_legacy_binary).build()

def default_testonly_test(name):
    native.genrule(
        name = name + "_script",
        outs = [name + "_subject.sh"],
        cmd = "printf '#!/bin/sh\\nexit 0\\n' > $@",
        executable = True,
    )
    script = ":" + name + "_script"
    _wrapped_binary(
        name = name + "_subject",
        args = ["$(location %s)" % script],
        data = [script],
        srcs = [script],
    )
    analysis_test(name = name, target = ":" + name + "_subject", impl = _check)

def _check(env, target):
    env.expect.that_bool(target[DefaultInfo].files_to_run.executable != None).equals(True)
