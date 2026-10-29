visibility("private")

SettingInfo = provider(fields = ["operation", "value"])

RuleInfo = provider(fields = [
    # keep sorted
    "executable",
    "extension_parent",
    "implicit_targets",
    "kind",
    "native",
    "providers",
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
