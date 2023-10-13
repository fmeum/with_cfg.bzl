# with_cfg.bzl

This Starlark library makes it easy to create new rules that are variants of existing rules with modified [Bazel settings](https://bazel.build/reference/command-line-reference) via a builder.
It uses [transitions](https://bazel.build/extending/config#user-defined-transitions) to apply these settings to both the rule and its (transitive) dependencies.
It also supports resetting the modified settings to their original values for specific dependencies or entire attributes, which can help reduce build times by preventing unnecessary rebuilds of dependencies in different configurations.

## Setup

Add the following to your `MODULE.bazel` file, substituting `...` with the latest release version:

```starlark
bazel_dep(name = "with_cfg.bzl", version = "...")
```

## Basic usage

The following example creates an `opt_filegroup` rule that behaves like a `filegroup` but builds all its files with `--compilation_mode=opt`:

```starlark
# opt_filegroup.bzl
load("@with_cfg.bzl", "with_cfg")

opt_filegroup, _opt_filegroup_internal = with_cfg(
    native.filegroup,
).set(
    "compilation_mode",
    "opt",
).build()
```

Since the `filegroup` rule is used in a `.bzl` file, not a `BUILD` file, it has to be qualified with `native.`.
The second return value of `build()` has to be assigned to a variable, here called `_opt_filegroup_internal`, due to restrictions on rule definitions enforced by Bazel, but can otherwise be ignored.
The `opt_filegroup` rule can now be used just like `filegroup`.

See [examples/opt_filegroup](examples/opt_filegroup) for the complete example.

## Advanced usage

The following example creates a `cc_asan_test` rule that behaves like a `cc_test`, but instruments the test and all its dependencies with [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html).
It also comes with a "reset" rule `cc_asan_test_reset` that can be used to disable instrumentation for specific dependencies and also automatically doesn't apply the instrumentation to `data` dependencies and (generated) source files.

```starlark
# cc_asan_test.bzl
load("@with_cfg.bzl", "with_cfg")

cc_asan_test, cc_asan_test_reset = with_cfg(
    native.cc_test,
).extend(
    "copt",
    ["-fsanitize=address"],
).extend(
    "linkopt",
    select({
        # link.exe doesn't require or recognize -fsanitize=address and would emit a warning.
        "@rules_cc//cc/compiler:msvc-cl": [],
        "//conditions:default": ["-fsanitize=address"],
    }),
).resettable(
    Label(":cc_asan_test_original_settings"),
).reset_on_attrs(
    "data",
    "srcs",
).build()

# BUILD.bazel
load("@with_cfg.bzl", "original_settings")

original_settings(
    name = "cc_asan_test_original_settings",
)
```

See [examples/cc_asan_test_with_reset](examples/cc_asan_test_with_reset) for the complete example.

## Documentation

The symbols exported from `@with_cfg.bzl` are documented [here](docs/defs.md).

## Examples

- [cc_asan_test](examples/cc_asan_test/cc_asan_test.bzl): A `cc_test` that is always instrumented and run with [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html), including its dependencies.
- [cc_asan_test_with_reset](examples/cc_asan_test_with_reset/cc_asan_test.bzl): An advanced variant of `cc_asan_test` that uses `resettable()` and `reset_on_attrs()` to reduce build time by selectively disabling instrumentation for test data and certain dependencies.
- [cc_define_test](examples/cc_define_test/cc_define_test.bzl): A `cc_test` that propagates a define to all its transitive dependencies. This example shows that `with_cfg.bzl` transparently supports runfiles lookups, `select`s and other features of the underlying rule.
- [java_21_library](examples/java_21_library/java_21_library.bzl): A `java_library` that is always built targeting Java 21, even if the default Java configuration doesn't support it.
- [java_21_library_with_reset](examples/java_21_library_with_reset/java_21_library.bzl): An advanced variant of `java_21_library` that uses `resettable()` to build a legacy dependency of the library with Java 7.
- [opt_filegroup](examples/opt_filegroup/opt_filegroup.bzl): Build all files in a `filegroup` with `--compilation_mode` set to `opt`, for example to speed up an integration test using them.
