# Examples

- [cc_asan_test](cc_asan_test/cc_asan_test.bzl): A `cc_test` that is always instrumented and run with [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html), including its dependencies.
- [cc_asan_test_with_reset](cc_asan_test_with_reset/cc_asan_test.bzl): An advanced variant of `cc_asan_test` that uses `resettable()` and `reset_on_attrs()` to reduce build time by selectively disabling instrumentation for test data and certain dependencies.
- [cc_define_test](cc_define_test/cc_define_test.bzl): A `cc_test` that propagates a define to all its transitive dependencies. This example shows that `with_cfg.bzl` transparently supports runfiles lookups, `select`s and other features of the underlying rule.
- [java_21_library](java_21_library/java_21_library.bzl): A `java_library` that is always built targeting Java 21, even if the default Java configuration doesn't support it.
- [java_21_library_with_reset](java_21_library_with_reset/java_21_library.bzl): An advanced variant of `java_21_library` that uses `resettable()` to build a legacy dependency of the library with Java 7.
- [java_test_suite_multiple_jdks](java_test_suite_multiple_jdks/test_suite.bzl): Demonstrates how to use `create_jvm_test_suite` along with `with_cfg.bzl` to run Java test suites on multiple JDK versions separately
- [opt_filegroup](opt_filegroup/opt_filegroup.bzl): Build all files in a `filegroup` with `--compilation_mode` set to `opt`, for example to speed up an integration test using them.
