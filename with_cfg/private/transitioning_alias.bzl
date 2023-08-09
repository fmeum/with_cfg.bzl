load(":common.bzl", "FrontendInfo")
load(":setting.bzl", "get_attr_type", "validate_and_get_attr_name")

visibility("private")

def make_transitioning_alias(*, providers, transition, values):
    settings_attrs = {
        validate_and_get_attr_name(setting): getattr(attr, get_attr_type(value))()
        for setting, value in values.items()
    }
    return rule(
        implementation = _make_transitioning_alias_impl(providers = providers),
        attrs = settings_attrs | {
            # This attribute name is internal only, so it can only help to choose a
            # name that is treated as a dependency attribute by the IntelliJ plugin:
            # https://github.com/bazelbuild/intellij/blob/11acaac819346f74e930c47594f37d81e274efb1/aspect/intellij_info_impl.bzl#L29
            "exports": attr.label(
                allow_files = True,
                cfg = transition,
                mandatory = True,
            ),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    )

def _make_transitioning_alias_impl(*, providers):
    return lambda ctx: _transitioning_alias_base_impl(ctx, providers = providers)

def _transitioning_alias_base_impl(ctx, *, providers):
    # The transition on exports is a split transition with a single outgoing configuration.
    target = ctx.attr.exports[0]
    return [
        DefaultInfo(
            # Filter out executable to prevent an error since this rule doesn't
            # create the artifact.
            files = target[DefaultInfo].files,
            data_runfiles = target[DefaultInfo].data_runfiles,
            default_runfiles = target[DefaultInfo].default_runfiles,
        ),
        FrontendInfo(
            executable = target[DefaultInfo].files_to_run.executable,
            providers = providers,
            run_environment_info = target[RunEnvironmentInfo] if RunEnvironmentInfo in target else None,
        ),
    ] + [
        target[provider]
        for provider in providers
        if provider in target
    ]
