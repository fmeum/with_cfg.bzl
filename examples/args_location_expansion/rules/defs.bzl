load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _write_settings_rule_impl(ctx):
    # type: (ctx) -> None
    rule_setting = ctx.attr._rule_setting[BuildSettingInfo].value
    if rule_setting == "unset":
        fail("rule_setting is unset")
    with_cfg_setting = ctx.attr._with_cfg_setting[BuildSettingInfo].value
    if with_cfg_setting == "unset":
        fail("with_cfg_setting is unset")

    out = ctx.actions.declare_file(ctx.label.name + "_" + rule_setting[0] + "_" + with_cfg_setting[0])
    ctx.actions.write(out, "name:{},rule_setting:{},with_cfg_setting:{}\n".format(out.basename, rule_setting, with_cfg_setting))
    return [
        DefaultInfo(files = depset([out])),
        platform_common.TemplateVariableInfo({
            "SETTINGS_FILE": out.short_path,
        }),
    ]

write_settings_rule = rule(
    implementation = _write_settings_rule_impl,
    attrs = {
        "_rule_setting": attr.label(default = ":rule_setting"),
        "_with_cfg_setting": attr.label(default = ":with_cfg_setting"),
    },
)

def _data_transition_impl(_settings, _attr):
    return {
        "//args_location_expansion/rules:rule_setting": "rule",
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
    runfiles = ctx.runfiles()
    runfiles = runfiles.merge(ctx.attr.binary[DefaultInfo].default_runfiles)
    for target in ctx.attr.data:
        runfiles = runfiles.merge(ctx.runfiles(transitive_files = target[DefaultInfo].files))
        runfiles = runfiles.merge(target[DefaultInfo].data_runfiles)
    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
        RunEnvironmentInfo(
            environment = ctx.attr.env,
        ),
    ]

transitioned_test = rule(
    # Using a rule transition rather than a split transition on the data
    # attribute is crucial since it also has to apply to the predefined
    # toolchains attribute.
    cfg = _data_transition,
    implementation = _transitioned_test_impl,
    attrs = {
        "binary": attr.label(
            cfg = "target",
            executable = True,
        ),
        "data": attr.label_list(
            allow_files = True,
        ),
        "env": attr.string_dict(),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    test = True,
)
