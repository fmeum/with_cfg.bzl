visibility("private")

DEFAULT_PROVIDERS = [
    # RunEnvironmentInfo can't be returned from a non-executable, non-test rule and thus requires
    # special handling so that it isn't returned by the transitioning alias.
    AnalysisTestResultInfo,
    CcInfo,
    CcToolchainConfigInfo,
    DebugPackageInfo,
    InstrumentedFilesInfo,
    JavaInfo,
    JavaPluginInfo,
    OutputGroupInfo,
    PyInfo,
    PyRuntimeInfo,
    apple_common.AppleDebugOutputs,
    apple_common.AppleDynamicFramework,
    apple_common.AppleExecutableBinary,
    apple_common.Objc,
    apple_common.XcodeProperties,
    apple_common.XcodeVersionConfig,
    config_common.FeatureFlagInfo,
    java_common.BootClassPathInfo,
    java_common.JavaRuntimeInfo,
    java_common.JavaToolchainInfo,
    platform_common.TemplateVariableInfo,
    platform_common.ToolchainInfo,
]

IMPLICIT_TARGETS = {
    "cc_binary": [
        "{name}.dwp",
        "{name}.stripped",
    ],
    "java_binary": [
        "{name}.jar",
        "{name}-src.jar",
        "{name}_deploy.jar",
        "{name}_deploy-src.jar",
    ],
    "java_library": [
        # It is not a typo that this uses `{name}` rather than `{basename}`: a java_library with
        # `name = "dir/foo"` will product a jar at `libdir/foo.jar`, not `dir/libfoo.jar`.
        "lib{name}.jar",
        "lib{name}-src.jar",
    ],
    "java_test": [
        "{name}.jar",
    ],
}
