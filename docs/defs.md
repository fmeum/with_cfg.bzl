<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="original_settings"></a>

## original_settings

<pre>
original_settings(<a href="#original_settings-name">name</a>)
</pre>

Stores the original settings modified by a "resettable" rule constructed with `with_cfg`.

Targets of this rule are only created for [`with_cfg`](#with_cfg)'s `resettable()` method. A
single target of this rule should be created for each resettable rule created with `with_cfg`,
in the BUILD file where the resettable rule is defined.

`visibility` does not need to be set.

Example:
```python
# pkg/defs.bzl
load("@with_cfg.bzl", "with_cfg")
my_foo_binary, _my_foo_binary_internal = with_cfg(
    foo_binary
).set(
    "platforms",
    [Label("//platforms:my_platform")],
).resettable(
    Label(":my_foo_binary_original_settings"),
).build()

# pkg/BUILD.bazel
load("@with_cfg.bzl", "original_settings")

original_settings(
    name = "my_foo_binary_original_settings",
)
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="original_settings-name"></a>name |  The name of the target.   |  none |


<a id="with_cfg"></a>

## with_cfg

<pre>
with_cfg(<a href="#with_cfg-kind">kind</a>, <a href="#with_cfg-executable">executable</a>, <a href="#with_cfg-implicit_targets">implicit_targets</a>, <a href="#with_cfg-extra_providers">extra_providers</a>)
</pre>

Creates a new rule out of an existing one with modified Bazel flags or build settings.

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


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="with_cfg-kind"></a>kind |  The rule (or macro) to use as a base.   |  none |
| <a id="with_cfg-executable"></a>executable |  Whether the base rule is executable.<br><br>Defaults to `True` if the name of the base rule name ends with `_binary`.   |  `None` |
| <a id="with_cfg-implicit_targets"></a>implicit_targets |  A list of patterns of implicit targets provided by the base rule.<br><br>A pattern is evaluated with `format` and supplied the following variables: <ul>   <li>`{name}`: The full name of the target (e.g. `subdir/my_target`).   <li>`{basename}`: The basename of the target (e.g. `my_target`).   <li>`{dirprefix}`: The directory prefix of the target (e.g. `subdir/`, usually empty). </ul> Not required for rules shipped with Bazel (`cc_*`, `java_*`).   |  `None` |
| <a id="with_cfg-extra_providers"></a>extra_providers |  Additional providers to forward from the base rule or macro.   |  `[]` |

**RETURNS**

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


