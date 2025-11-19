load(":args.bzl", "args_aspect")
load(":providers.bzl", "ArgsInfo", "FrontendInfo", "OriginalSettingsInfo")
load(":setting.bzl", "get_attr_type", "validate_and_get_attr_name")

visibility("private")

def make_transitioning_alias(*, providers, transition, values, original_settings_label):
    settings_attrs = {
        validate_and_get_attr_name(setting): getattr(attr, get_attr_type(value))()
        for setting, value in values.items()
    }
    if original_settings_label:
        resettable_attrs = {
            "internal_only_reset": attr.bool(default = True),
            # Fail if the original_settings_label doesn't have the correct provider.
            "_original_settings": attr.label(
                default = original_settings_label,
                providers = [OriginalSettingsInfo],
            ),
        }
    else:
        resettable_attrs = {}
    return rule(
        implementation = _make_transitioning_alias_impl(providers = providers),
        attrs = settings_attrs | resettable_attrs | {
            # This attribute name is internal only, so it can only help to choose a name that is
            # treated as a dependency attribute by the IntelliJ plugin:
            # https://github.com/bazelbuild/intellij/blob/11acaac819346f74e930c47594f37d81e274efb1/aspect/intellij_info_impl.bzl#L29
            "exports": attr.label(
                allow_files = True,
                cfg = transition,
                aspects = [args_aspect],
            ),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    )

def _make_transitioning_alias_impl(*, providers):
    return lambda ctx: _transitioning_alias_base_impl(ctx, providers = providers)

def _transitioning_alias_base_impl(ctx, *, providers):
    is_reset_rule = getattr(ctx.attr, "internal_only_reset", False)

    # The transition on exports is a split transition with a single outgoing configuration.
    target = ctx.attr.exports[0]
    returned_providers = [
        target[provider]
        for provider in providers
        if provider in target
    ] + [
        DefaultInfo(
            # Filter out executable to prevent an error since this rule doesn't create the artifact.
            files = target[DefaultInfo].files,
            data_runfiles = target[DefaultInfo].data_runfiles,
            default_runfiles = target[DefaultInfo].default_runfiles,
        ),
        coverage_common.instrumented_files_info(
            ctx = ctx,
            dependency_attributes = ["exports"],
        ),
    ]
    if not is_reset_rule:
        returned_providers.append(FrontendInfo(
            executable = target[DefaultInfo].files_to_run.executable,
            providers = providers,
            run_environment_info = target[RunEnvironmentInfo] if RunEnvironmentInfo in target else None,
            template_variable_info = target[ArgsInfo].template_variable_info if ArgsInfo in target else None,
        ))

    return returned_providers
