visibility("private")

SettingInfo = provider(fields = ["operation", "value"])

RuleInfo = provider(fields = [
    # keep sorted
    "executable",
    "implicit_targets",
    "kind",
    "native",
    "providers",
    "test",
])

FrontendInfo = provider(fields = ["executable", "providers", "run_environment_info"])
