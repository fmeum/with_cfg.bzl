load(":builder.bzl", "make_builder")
load(":common.bzl", "RuleInfo")
load(":rule_defaults.bzl", "DEFAULT_PROVIDERS", "IMPLICIT_TARGETS")

visibility("//with_cfg/...")

# A globally unique string used to validate that implicit target patterns contain a single
# placeholder.
_PATTERN_VALIDATION_MARKER = "with_cfg!-~+this string is pretty unique"

def with_cfg(
        kind,
        *,
        executable = None,
        implicit_targets = None,
        extra_providers = []):
    """Creates a new rule out of an existing one with modified Bazel flags or build settings.

    Example:
    ```python
    load("@with_cfg//with_cfg:defs.bzl", "with_cfg")

    my_foo_binary, _1 = with_cfg(foo_binary).set(
        "platforms", [Label("//platforms:my_platform")]
    ).extend(
        Label("//config:foo_opts"), ["--bar", "--baz"]
    ).build()
    ```

    Args:
      kind: The rule (or macro) to use as a base.
      executable: Whether the base rule is executable.

        Defaults to `True` if the name of the base rule name ends with `_binary`.
      implicit_targets: A list of patterns of implicit targets provided by the base rule.

        Every pattern must contain a single `{}` placeholder for the target name.
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
        entries of `value` are appended to the current value. `value` has to be a list or a
        `select` expression evaluating to a list. This is useful for repeatable settings such as
        `copt`.
      * `build()`: Returns a pair of:

        * a macro that behaves like the original rule, except that the targets created from it *and
          all their transitive dependencies* have the Bazel flags and user-defined build settings
          supplied to `set` and `extend` set to the given values.
        * a rule internally used by the macro that has to be assigned to a global variable in a
          `.bzl` file to comply with Bazel restrictions. It is recommended to chose a name starting
          with `_` as the rule should not be exported or used directly. While the exact name does
          not matter, it does show up in `query --output=build` output, can match `query`'s `kind`
          operator, and must not end with `_test`.
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
        if pattern.format(_PATTERN_VALIDATION_MARKER).count(_PATTERN_VALIDATION_MARKER) != 1:
            fail("Implicit target pattern must contain exactly one '{}' placeholder: " + pattern)

    rule_info = RuleInfo(
        kind = kind,
        executable = executable,
        test = test,
        implicit_targets = implicit_targets,
        providers = DEFAULT_PROVIDERS + extra_providers,
        native = _is_native(kind),
    )
    return make_builder(rule_info)

def get_rule_name(rule_or_macro):
    s = str(rule_or_macro)
    if s.startswith("<rule "):
        return s.removeprefix("<rule ").removesuffix(">")
    elif s.startswith("<built-in rule "):
        return s.removeprefix("<built-in rule ").removesuffix(">")
    elif s.startswith("<function "):
        return s.removeprefix("<function ").removesuffix(">").partition(" from ")[0]
    else:
        fail("Not a rule or macro: " + s)

def is_executable(rule_name):
    return rule_name.endswith("_binary")

def is_test(rule_name):
    return rule_name.endswith("_test")

def _is_native(rule_or_macro):
    return str(rule_or_macro).startswith("<built-in rule ")

def get_implicit_targets(rule_name):
    return IMPLICIT_TARGETS.get(rule_name, [])
