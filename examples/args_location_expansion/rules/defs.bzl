def _write_settings_rule_impl(ctx):
    # type: (ctx) -> None
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(out,
"""\
name = {}
rule_setting = {}
with_cfg_setting = {}
""".format(ctx.label.name, ctx.attr._rule_setting, ctx.attr._with_cfg_setting))
    return [DefaultInfo(files = depset([out]))]

write_settings_rule = rule(
    implementation = _write_settings_rule_impl,
    attrs = {
        "_rule_setting": attr.label(default = ":rule_setting"),
        "_with_cfg_setting": attr.label(default = ":with_cfg_setting"),
    },
)

def _data_transition_impl(_settings, _attr):
    return {
        "//args_location_expansion/rules:rule_setting": "set by rule transition",
    }

_data_transition = transition(
    implementation = _data_transition_impl,
    inputs = ["//args_location_expansion/rules:rule_setting"],
    outputs = ["//args_location_expansion/rules:rule_setting"],
)

def _transitioned_test_impl(ctx):
    # type: (ctx) -> None
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = executable, target_file = ctx.executable.binary)
    runfiles = ctx.runfiles().merge_all([target[DefaultInfo].default_runfiles for target in ctx.attr.data])
    runfiles = runfiles.merge(ctx.attr.binary[DefaultInfo].default_runfiles)
    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
    ]

transitioned_test = rule(
    implementation = _transitioned_test_impl,
    attrs = {
        "binary": attr.label(
            cfg = "target",
            executable = True,
        ),
        "data": attr.label_list(
            cfg = _data_transition,
            allow_files = True,
        ),
    },
    test = True,
)
