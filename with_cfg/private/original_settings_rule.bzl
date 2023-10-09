load(":providers.bzl", "OriginalSettingsInfo")

visibility("private")

def _original_settings_impl(ctx):
    return [
        OriginalSettingsInfo(
            json = ctx.build_setting_value,
        ),
    ]

original_settings = rule(
    implementation = _original_settings_impl,
    build_setting = config.string(flag = False),
    provides = [OriginalSettingsInfo],
)
