visibility("private")

DEFAULT_PROVIDERS = [
    # RunEnvironmentInfo can't be returned from a non-executable, non-test rule and thus requires
    # special handling so that it isn't returned by the transitioning alias.
    AnalysisTestResultInfo,
    CcInfo,
    CcToolchainConfigInfo,
    DebugPackageInfo,
    InstrumentedFilesInfo,
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
        "{}.dwp",
        "{}.stripped",
    ],
    "java_binary": [
        "{}.jar",
        "{}-src.jar",
        "{}_deploy.jar",
        "{}_deploy-src.jar",
    ],
    "java_library": [
        "lib{}.jar",
        "lib{}-src.jar",
    ],
    "java_test": [
        "{}.jar",
        "{}_deploy.jar",
    ],
}
