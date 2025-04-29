load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/common:debug_package_info.bzl", "DebugPackageInfo")
load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")

visibility("private")

SPECIAL_CASED_PROVIDERS = [
    DefaultInfo,
    # Forwarding is handled by coverage_common.instrumented_files_info.
    InstrumentedFilesInfo,
    # RunEnvironmentInfo can't be returned from a non-executable, non-test rule and thus requires
    # special handling so that it isn't returned by the transitioning alias.
    RunEnvironmentInfo,
]

DEFAULT_PROVIDERS = [
    p
    for p in [
        AnalysisTestResultInfo,
        CcInfo,
        CcToolchainConfigInfo,
        DebugPackageInfo,
        JavaInfo,
        JavaPluginInfo,
        OutputGroupInfo,
        bazel_features.globals.PyInfo,
        bazel_features.globals.PyRuntimeInfo,
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
    if p
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
