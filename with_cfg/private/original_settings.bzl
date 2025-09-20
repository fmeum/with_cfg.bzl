load(":original_settings_rule.bzl", _original_settings = "original_settings")

visibility("//with_cfg")

def original_settings(*, name):
    """Stores the original settings modified by a "resettable" rule constructed with `with_cfg`.

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

    Args:
      name: The name of the target.
    """
    _original_settings(
        name = name,
        build_setting_default = "",
        visibility = ["//visibility:private"],
    )
