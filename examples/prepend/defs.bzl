"""Prepend options before the flags supplied by the caller."""

load("@with_cfg.bzl", "with_cfg")

def _options_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, "\n".join(ctx.build_setting_value) + "\n")
    return [DefaultInfo(files = depset([out]))]

options = rule(
    implementation = _options_impl,
    build_setting = config.string_list(flag = True),
)

prepend_filegroup, _prepend_filegroup_internal = with_cfg(native.filegroup).prepend(
    Label(":options"),
    ["first", "second"],
).build()

empty_prepend_filegroup, _empty_prepend_filegroup_internal = with_cfg(native.filegroup).prepend(
    Label(":options"),
    [],
).build()
