load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":providers.bzl", "FrontendInfo")

visibility("private")

def get_frontend(*, executable, test):
    if test:
        return _frontend_test
    elif executable:
        return _frontend_executable
    else:
        return _frontend_default

unwrap_template_variable_info = rule(
    doc = "Extracts the TemplateVariableInfo from the FrontendInfo provider.",
    implementation = lambda ctx: ctx.attr.exports[FrontendInfo].template_variable_info,
    attrs = {
        "exports": attr.label(
            mandatory = True,
            providers = [FrontendInfo],
        ),
    },
)

def _frontend_impl(ctx):
    # type: (ctx) -> None
    target = ctx.attr.exports

    original_executable = target[FrontendInfo].executable
    executable_basename = original_executable.basename
    incompatible_same_depth_path_layout = ctx.attr._incompatible_same_depth_path_layout[BuildSettingInfo].value
    if incompatible_same_depth_path_layout:
        # Create the executable in a subdirectory to ensure that its path depth below the exec root
        # is the same as the original executable's. This is necessary to make relative RPATHS work.
        executable = ctx.actions.declare_file(ctx.label.name + "/" + executable_basename)
    else:
        dirname, separator, _ = ctx.label.name.rpartition("/")
        executable = ctx.actions.declare_file(dirname + separator + executable_basename)

    additional_runfiles = [executable]
    if CcInfo in target and ctx.target_platform_has_constraint(ctx.attr._windows[platform_common.ConstraintValueInfo]):
        # DLLs need to be located next to the executable on Windows.
        dlls_to_relocate = [
            f
            for f in target[DefaultInfo].default_runfiles.files.to_list()
            if f.path.endswith(".dll") and f.dirname != executable.dirname and f.dirname == original_executable.dirname
        ]
        for dll in dlls_to_relocate:
            out_dll = ctx.actions.declare_file(dll.basename, sibling = executable)
            ctx.actions.symlink(output = out_dll, target_file = dll)
            additional_runfiles.append(out_dll)

    ctx.actions.symlink(output = executable, target_file = original_executable)
    data_runfiles = ctx.runfiles(additional_runfiles).merge(target[DefaultInfo].data_runfiles)
    default_runfiles = ctx.runfiles(additional_runfiles).merge(target[DefaultInfo].default_runfiles)

    run_environment_info = target[FrontendInfo].run_environment_info or RunEnvironmentInfo(
        environment = ctx.attr.env,
        inherited_environment = ctx.attr.env_inherit,
    )
    return [
        DefaultInfo(
            executable = executable,
            files = target[DefaultInfo].files,
            data_runfiles = data_runfiles,
            default_runfiles = default_runfiles,
        ),
        coverage_common.instrumented_files_info(
            ctx = ctx,
            dependency_attributes = ["exports"],
        ),
    ] + [
        target[provider]
        for provider in target[FrontendInfo].providers
        if provider in target
    ] + (
        [run_environment_info] if run_environment_info else []
    )

_frontend_attrs = {
    "data": attr.label_list(allow_files = True),
    "env": attr.string_dict(),
    "env_inherit": attr.string_list(),
    # This attribute name is internal only, so it can only help to choose a
    # name that is treated as a dependency attribute by the IntelliJ plugin:
    # https://github.com/bazelbuild/intellij/blob/11acaac819346f74e930c47594f37d81e274efb1/aspect/intellij_info_impl.bzl#L29
    "exports": attr.label(
        mandatory = True,
        providers = [FrontendInfo],
    ),
    "_windows": attr.label(default = "@platforms//os:windows"),
    "_incompatible_same_depth_path_layout": attr.label(default = "//:incompatible_same_depth_path_layout"),
}

_frontend_test_attrs = {
    "_lcov_merger": attr.label(
        default = configuration_field(fragment = "coverage", name = "output_generator"),
        executable = True,
        cfg = config.exec("test"),
    ),
    "_collect_cc_coverage": attr.label(
        default = "@bazel_tools//tools/test:collect_cc_coverage",
        executable = True,
        cfg = config.exec("test"),
    ),
}

_frontend_executable = rule(_frontend_impl, attrs = _frontend_attrs, executable = True)
_frontend_test = rule(_frontend_impl, attrs = _frontend_attrs | _frontend_test_attrs, test = True)

def _frontend_default(*, name, exports, **kwargs):
    native.alias(
        name = name,
        actual = exports,
        **kwargs
    )
