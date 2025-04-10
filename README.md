# with_cfg.bzl

This Starlark library makes it easy to create new rules that are variants of existing rules with modified [Bazel settings](https://bazel.build/reference/command-line-reference), applied to both the rule itself and its (transitive) dependencies via [transitions](https://bazel.build/extending/config#user-defined-transitions).

[BazelCon 2023 talk](https://youtube.com/watch?v=U5bdQRQY-io&list=PLxNYxgaZ8Rsefrwb_ySGRi_bvQejpO_Tj&index=14&pp=iAQB)

## Setup

Add the following to your `MODULE.bazel` file, substituting `...` with the latest release version:

```starlark
bazel_dep(name = "with_cfg.bzl", version = "...")
```

## Basic usage

All functionality is provided by the `with_cfg` function defined in `@with_cfg.bzl`, which accepts an existing rule (or macro) as an argument and returns a builder for a new rule with modified Bazel settings.

The following example creates an `opt_filegroup` rule that behaves like a `filegroup` but builds all its files with `--compilation_mode=opt`:

```starlark
# opt_filegroup.bzl
load("@with_cfg.bzl", "with_cfg")

opt_filegroup, _opt_filegroup_internal = with_cfg(native.filegroup).set("compilation_mode", "opt").build()
```

Since the `filegroup` rule is used in a `.bzl` file, not a `BUILD` file, it has to be qualified with `native.`.
The second return value of `build()` has to be assigned to a variable, here called `_opt_filegroup_internal`, due to restrictions on rule definitions enforced by Bazel, but can otherwise be ignored.
The `opt_filegroup` rule can now be used just like `filegroup`.

See [examples/opt_filegroup](examples/opt_filegroup) for the complete example.

## Advanced usage

`with_cfg` also supports resetting the modified settings to their original values for specific dependencies or entire attributes, which can help reduce build times by preventing unnecessary rebuilds of dependencies in different configurations.

The following example creates a `cc_asan_test` rule that behaves like a `cc_test`, but instruments the test and all its dependencies with [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html).
It also comes with a "reset" rule `cc_asan_test_reset` that can be used to disable instrumentation for specific dependencies and also automatically doesn't apply the instrumentation to `data` dependencies and (generated) source files.

```starlark
# cc_asan_test.bzl
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.cc_test)
_builder.extend("copt", ["-fsanitize=address"])
_builder.extend("linkopt", select({
    # link.exe doesn't require or recognize -fsanitize=address and would emit a warning.
    "@rules_cc//cc/compiler:msvc-cl": [],
    "//conditions:default": ["-fsanitize=address"],
}))
_builder.resettable(Label(":cc_asan_test_original_settings"))
_builder.reset_on_attrs("data", "srcs")
cc_asan_test, cc_asan_test_reset = _builder.build()

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

See [examples](examples) for more examples.
