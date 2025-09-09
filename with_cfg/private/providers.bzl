visibility("private")

SettingInfo = provider(fields = ["operation", "value"])

RuleInfo = provider(fields = [
    # keep sorted
    "executable",
    "implicit_targets",
    "kind",
    "native",
    "providers",
    "supports_extension",
    "supports_inheritance",
    "test",
])

ArgsInfo = provider(fields = [
    "template_variable_info",
])

FrontendInfo = provider(fields = [
    "executable",
    "providers",
    "run_environment_info",
    "template_variable_info",
])

OriginalSettingsInfo = provider(fields = ["json"])
