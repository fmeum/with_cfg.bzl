load("@rules_uv//uv:pip.bzl", "pip_compile")
load("@with_cfg.bzl", "with_cfg")

pip_compile_py3_8, _pip_compile_py3_8_internal = with_cfg(
    pip_compile,
    implicit_targets = ["{name}_diff_test"],
    # Necessary since this rule doesn't have a name that ends with _binary.
    executable = True,
).set(
    Label("@rules_python//python/config_settings:python_version"),
    "3.8",
).build()
