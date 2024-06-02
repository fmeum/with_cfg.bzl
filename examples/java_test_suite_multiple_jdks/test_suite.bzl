load("@contrib_rules_jvm//java:defs.bzl", "create_jvm_test_suite")
load("@rules_java//java:defs.bzl", "java_library")

def multi_jdk_test_suite(
        name,
        srcs = [],
        deps = [],
        test_runners = {}):
    """A macro similiar to java_test_suite from contrib_rules_jvm but creates multiple variations of each test based on the 'test_runners' argument.

    Args:
        name: The base name of the test suite.
        srcs: A list of source files to include in the test suite.
        deps: A list of dependencies to include in the test suite.
        test_runners: A dict where the keys are suffixes to be appended to the
            name of each test target in the suite, and the values are the rule
            functions to use to define those test variants (e.g. java_17_junit5_test
            or java_21_junit5_test).
    """

    if not srcs:
        fail("srcs is required")

    if not test_runners:
        fail("test_runners is required")

    def _define_library(name, **kwargs):
        java_library(
            name = name,
            **kwargs
        )

    # call create_jvm_test_suite once per test runner, to allow for e.g.
    # defining/running test targets on different JDK versions
    for name_suffix, define_test_fn in test_runners.items():
        # create_jvm_test_suite expects the function passed in the 'define_test'
        # attr to return the name of the target

        # normally the define_test_fn would be passed to create_jvm_test_suite
        # directly, but we want to customize the logic: when we are creating
        # more than 1 test suite, we need to customize the name of each
        # individual test target to avoid reusing the same target names (which
        # will cause a Bazel error).
        #
        # Being able to customize the 'define_test' function is the entire
        # reason why we call create_jvm_test_suite() here, rather than
        # java_test_suite().
        def wrapped_test_fn(name, **kwargs):
            test_name = name if name_suffix == "" else name + "-" + name_suffix
            define_test_fn(name = test_name, **kwargs)
            return test_name

        create_jvm_test_suite(
            name = name if name_suffix == "" else name + "-" + name_suffix,
            srcs = srcs,
            # runner = runner,
            package = None,  # set to None to have rule infer package name
            define_library = _define_library,
            define_test = wrapped_test_fn,
            test_suffixes = ["Test.java"],
            deps = [dep for dep in deps],
        )
