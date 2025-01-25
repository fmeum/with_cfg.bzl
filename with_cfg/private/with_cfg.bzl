load("@bazel_features//:features.bzl", "bazel_features")
load(":builder.bzl", "make_builder")
load(":providers.bzl", "RuleInfo")
load(":rule_defaults.bzl", "DEFAULT_PROVIDERS", "IMPLICIT_TARGETS", "SPECIAL_CASED_PROVIDERS")

visibility("//with_cfg/...")

# A globally unique string used to validate that implicit target patterns contain a single
# placeholder.
_PATTERN_VALIDATION_MARKER = "with_cfg!-~+this string is pretty unique"

# buildifier: disable=unnamed-macro
def with_cfg(
        kind,
        *,
        executable = None,
        implicit_targets = None,
        extra_providers = []):
    """Creates a new rule out of an existing one with modified Bazel flags or build settings.

    Example:
    ```python
    load("@with_cfg.bzl", "with_cfg")

    my_foo_binary, _my_foo_binary_internal = with_cfg(
        foo_binary
    ).set(
        "platforms",
        [Label("//platforms:my_platform")],
    ).extend(
        Label("//config:foo_opts"),
        ["--bar", "--baz"],
    ).build()
    ```

    Args:
      kind: The rule (or macro) to use as a base.
      executable: Whether the base rule is executable.

        Defaults to `True` if the name of the base rule name ends with `_binary`.
      implicit_targets: A list of patterns of implicit targets provided by the base rule.

        A pattern is evaluated with `format` and supplied the following variables:
        <ul>
          <li>`{name}`: The full name of the target (e.g. `subdir/my_target`).
          <li>`{basename}`: The basename of the target (e.g. `my_target`).
          <li>`{dirprefix}`: The directory prefix of the target (e.g. `subdir/`, usually empty).
        </ul>
        Not required for rules shipped with Bazel (`cc_*`, `java_*`).
      extra_providers: Additional providers to forward from the base rule or macro.

    Returns:
      A builder with the following methods:

      * `set(setting, value)`: If `setting` is a string (e.g. `java_runtime_version`), then the
        corresponding native Bazel flag (e.g. `--java_runtime_version`) is set to `value`. If
        `setting` is a [`Label`](https://bazel.build/rules/lib/builtins/Label) of a [user-defined
        build setting](https://bazel.build/extending/config#user-defined-build-settings), then that
        setting is set to `value`. `value` can be a `select` expression.
      * `extend(setting, value)`: Like `set`, but instead of setting the setting to `value`, the
        entries of `value` are appended to the current value if it doesn't already have them as a
        suffix. `value` has to be a list or a `select` expression evaluating to a list. This is
        useful for repeatable settings such as `copt`.
      * `resettable(original_settings_label)`: If called on the builder, the resulting rule will
        store the original values of the settings it modifies in the
        [`original_settings`](#original_settings) target referenced by the `Label`
        `original_settings_label`. This allows users to reset the settings to their original values
        for certain dependencies by wrapping them in the reset rule returned by the `build()` method
        (see below). The [`original_settings`](#original_settings) target should be declared in the
        package containing the `.bzl` file with the `with_cfg` call.

        Using `resettable` requires the Bazel flag `--experimental_output_directory_naming_scheme`
        to be set to `diff_against_dynamic_baseline`, which is the default as of Bazel 7.
      * `reset_on_attrs(*attrs)`: If called with one or more attribute names, the settings modified
        via `set()` and `extend()` are automatically reset to their original values for all
        dependencies listed in any of these attributes. This requires `resettable()` to be called on
        the builder and is equivalent to manually wrapping each dependency with the reset rule.
      * `build()`: Returns a pair of:

        * a macro that behaves like the original rule, except that the targets created from it *and
          all their transitive dependencies* have the Bazel flags and user-defined build settings
          supplied to `set` and `extend` set to the given values.
        * a rule that depends on whether `resettable()` has been called on the builder:

          * If `resettable()` has not been called, this rule is only used internally by the macro,
            but has to be assigned to a global variable in a `.bzl` file to comply with Bazel
            restrictions. It is recommended to chose a name starting with `_` as the rule should not
            be exported or used directly. While the exact name does not matter, it does show up in
            `query --output=build` output, can match `query`'s `kind` operator, and must not end
            with `_test`.
          * If `resettable()` has been called, this rule is the reset rule that can be used to
            return the settings modified by the macro to their original values for specific
            dependencies. The reset rule has a single attribute, `exports`, which accepts a single
            label. The rule will forward all builtin providers as well as the ones specified in
            `extra_providers` from the "exported" target after resetting the settings for it.

        build() can only be called once on a builder. Subsequent calls to other methods except
        `clone()` will fail.
      * `clone()`: Returns a new builder with the same rule and settings as the original one, but
        acts as if `resettable()` and `reset_on_attrs()` have not been called. `set` and `extend`
        can be called on this builder even for settings that had already been added to the original
        builder. This is useful to create multiple rules with slightly different settings.
    """
    rule_name = get_rule_name(kind)

    if executable == None:
        executable = is_executable(rule_name)

    # Bazel enforces that a rule is a test rule if and only if its name ends with "_test", so we
    # do not allow overriding this.
    test = is_test(rule_name)
    if implicit_targets == None:
        implicit_targets = get_implicit_targets(rule_name)

    # Validate implicit target patterns eagerly for better error messages.
    for pattern in implicit_targets:
        if _PATTERN_VALIDATION_MARKER not in pattern.format(
            name = _PATTERN_VALIDATION_MARKER,
            basename = _PATTERN_VALIDATION_MARKER,
            dirprefix = _PATTERN_VALIDATION_MARKER,
        ):
            fail("Implicit target pattern must contain {name} or {dirprefix} and {basename}: %s" % pattern)

    rule_info = RuleInfo(
        kind = kind,
        executable = executable,
        test = test,
        implicit_targets = implicit_targets,
        providers = _all_providers(extra_providers),
        native = _is_native(kind),
        supports_inheritance = _supports_inheritance(kind),
        supports_extension = _supports_extension(kind),
    )
    return make_builder(rule_info)

def get_rule_name(kind):
    s = str(kind)
    if s.startswith("<rule "):
        return s.removeprefix("<rule ").removesuffix(">")
    elif s.startswith("<macro "):
        return s.removeprefix("<macro ").removesuffix(">")
    elif s.startswith("<built-in rule "):
        return s.removeprefix("<built-in rule ").removesuffix(">")
    elif s.startswith("<function "):
        return s.removeprefix("<function ").removesuffix(">").partition(" from ")[0]
    else:
        fail("Not a rule or macro: " + s)

def is_executable(rule_name):
    return rule_name.endswith("_binary")

def is_test(rule_name):
    # rules_go's go_test is a macro called go_test_macro. Macro wrappers should
    # generally try to have the same name as the rule they are wrapping, so this
    # shouldn't become configurable.
    return rule_name.endswith("_test") or rule_name == "go_test_macro"

def _is_native(kind):
    return str(kind).startswith("<built-in rule ")

def _supports_inheritance(kind):
    # Legacy macros don't support inheritance.
    return not str(kind).startswith("<function ")

# Rules that need https://github.com/bazelbuild/bazel/pull/24778 to be extendable.
_NOT_EXTENDABLE = [
    # keep sorted
    "cc_binary",
    "cc_test",
] if not bazel_features.cc.rules_support_extension else []

def _supports_extension(kind):
    kind_str = str(kind)
    return kind_str.startswith("<rule ") and get_rule_name(kind_str) not in _NOT_EXTENDABLE

def get_implicit_targets(rule_name):
    return IMPLICIT_TARGETS.get(rule_name, [])

def _all_providers(extra_providers):
    if not extra_providers:
        return DEFAULT_PROVIDERS
    all_providers = list(DEFAULT_PROVIDERS)

    # Providers aren't hashable.
    # TODO: Improve this after https://github.com/bazelbuild/bazel/pull/24848.
    for p in extra_providers:
        if p not in all_providers and p not in SPECIAL_CASED_PROVIDERS:
            all_providers.append(p)
    return all_providers
