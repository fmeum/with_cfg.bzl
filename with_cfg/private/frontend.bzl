load(":providers.bzl", "FrontendInfo")

visibility("private")

def get_frontend(*, executable, test):
    if test:
        return _frontend_test
    elif executable:
        return _frontend_executable
    else:
        return _frontend_default

def _frontend_impl(ctx):
    target = ctx.attr.exports

    original_executable = target[FrontendInfo].executable
    dirname, separator, basename = ctx.label.name.rpartition("/")
    executable_basename = original_executable.basename
    executable = ctx.actions.declare_file(dirname + separator + basename + "/" + executable_basename)

    # TODO: If this is a copy rather than a symlink, runfiles discovery will not work correctly.
    #       Fix this by using a wrapper script rather than a symlink.
    ctx.actions.symlink(output = executable, target_file = original_executable)
    data_runfiles = ctx.runfiles([executable]).merge(target[DefaultInfo].data_runfiles)
    default_runfiles = ctx.runfiles([executable]).merge(target[DefaultInfo].default_runfiles)

    run_environment_info = _clean_run_environment_info(
        target[FrontendInfo].run_environment_info,
    ) or RunEnvironmentInfo(
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

# Workaround for https://github.com/bazelbuild/bazel/pull/20349:
# In Bazel 6.4.0, cc_test manually sets LCOV_MERGER to the lcov_merger executable in its own
# configuration, which is not the configuration of the top-level test wrapping it when that happens
# through a transition. Remove the variable to let TestActionBuilder set it to the correct value
# instead.
# TODO: Remove this workaround eventually.
def _clean_run_environment_info(run_environment_info):
    if not run_environment_info or not "LCOV_MERGER" in run_environment_info.environment:
        return run_environment_info
    cleaned_environment = {
        key: value
        for key, value in run_environment_info.environment.items()
        if key != "LCOV_MERGER"
    }
    return RunEnvironmentInfo(
        environment = cleaned_environment,
        inherited_environment = run_environment_info.inherited_environment,
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
}

_frontend_test_attrs = {
    "_lcov_merger": attr.label(
        default = configuration_field(fragment = "coverage", name = "output_generator"),
        executable = True,
        cfg = "exec",
    ),
    "_collect_cc_coverage": attr.label(
        default = "@bazel_tools//tools/test:collect_cc_coverage",
        executable = True,
        cfg = "exec",
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
