load(":args.bzl", "args_aspect")
load(":providers.bzl", "FrontendInfo", "OriginalSettingsInfo")
load(":setting.bzl", "get_rule_attrs")

visibility("private")

def make_transitioning_alias(*, providers, transition, operations, values, original_settings_label):
    if original_settings_label:
        resettable_attrs = {
            "internal_only_reset": attr.bool(default = True),
            # Fail if the original_settings_label doesn't have the correct provider.
            "_original_settings": attr.label(
                default = original_settings_label,
                providers = [OriginalSettingsInfo],
            ),
            # Fail if --experimental_output_directory_naming_scheme=diff_against_dynamic_baseline isn't set.
            "_check_for_diff_against_dynamic_baseline": attr.label(
                default = ":resettable_check_for_diff_against_dynamic_baseline",
            ),
        }
    else:
        resettable_attrs = {}
    return rule(
        implementation = _make_transitioning_alias_impl(providers = providers),
        attrs = get_rule_attrs(operations = operations, values = values) | resettable_attrs | {
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
        ))

    return returned_providers
