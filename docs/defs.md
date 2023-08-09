<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="with_cfg"></a>

## with_cfg

<pre>
with_cfg(<a href="#with_cfg-kind">kind</a>, <a href="#with_cfg-executable">executable</a>, <a href="#with_cfg-implicit_targets">implicit_targets</a>, <a href="#with_cfg-extra_providers">extra_providers</a>)
</pre>

Creates a new rule out of an existing one with modified Bazel flags or build settings.

Example:
```python
load("@with_cfg//with_cfg:defs.bzl", "with_cfg")

my_foo_binary, _1 = with_cfg(foo_binary).set(
    "platforms", [Label("//platforms:my_platform")]
).extend(
    Label("//config:foo_opts"), ["--bar", "--baz"]
).build()
```


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="with_cfg-kind"></a>kind |  The rule (or macro) to use as a base.   |  none |
| <a id="with_cfg-executable"></a>executable |  Whether the base rule is executable.<br><br>Defaults to `True` if the name of the base rule name ends with `_binary`.   |  `None` |
| <a id="with_cfg-implicit_targets"></a>implicit_targets |  A list of patterns of implicit targets provided by the base rule.<br><br>Every pattern must contain a single `{}` placeholder for the target name. Not required for rules shipped with Bazel (`cc_*`, `java_*`).   |  `None` |
| <a id="with_cfg-extra_providers"></a>extra_providers |  Additional providers to forward from the base rule or macro.   |  `[]` |

**RETURNS**

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


