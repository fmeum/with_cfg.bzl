load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(native.java_binary)
_builder.set_by_attr(
    "platforms",
    attr.label(mandatory = True),
    attr_name = "target_platform",
    # --platforms is list-valued for legacy reasons, but we don't want to
    # expose that to the user.
    transform = lambda x: [x],
)
_builder.set_by_attr(
    "compilation_mode",
    attr.string(
        values = ["dbg", "fastbuild", "opt"],
        default = "opt",
    ),
)
java_platform_binary, _java_platform_binary = _builder.build()

# The rest of the file is only relevant for testing purposes.

# Verify that a dependency is built with --compilation_mode=opt and for
# macOS x86_64.
def _check_dep(ctx):
    executable = ctx.attr.dep[DefaultInfo].executable
    if "-opt" not in executable.path:
        fail("Dependency must be built with --compilation_mode=opt")
    if "macos" not in executable.path:
        fail("Dependency must be built for macOS")
    if "x86_64" not in executable.path:
        fail("Dependency must be built for x86_64")

check_dep = rule(
    implementation = _check_dep,
    attrs = {
        "dep": attr.label(
            cfg = "target",
            executable = True,
        ),
    },
)
