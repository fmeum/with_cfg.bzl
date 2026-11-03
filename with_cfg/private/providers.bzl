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

# TODO(https://github.com/bazelbuild/bazel/issues/32207): Use native field
# types when the minimum Bazel accepts them on provider declarations.
ArgsInfo = provider(fields = {
    "template_variable_info": "Variables exposed to the frontend.",  # type: TemplateVariableInfo
})

FrontendInfo = provider(fields = {
    "executable": "Executable forwarded from the wrapped target.",  # type: File | None
    "providers": "Provider keys forwarded by the frontend.",  # type: Sequence[ProviderKey]
    "run_environment_info": "Run environment of the wrapped target.",  # type: RunEnvironmentInfo | None
    "template_variable_info": "Template variables of the wrapped target.",  # type: TemplateVariableInfo | None
})

OriginalSettingsInfo = provider(fields = {
    "json": "JSON encoding of the original settings.",  # type: str
})
