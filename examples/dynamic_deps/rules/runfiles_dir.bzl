def _runfiles_dir_impl(ctx):
    # type: (ctx) -> list
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    default_info = ctx.attr.executable[DefaultInfo]
    executable = default_info.files_to_run.executable
    name = executable.basename

    args = ctx.actions.args()
    args.add(out_dir.path)

    ctx.actions.run_shell(
        inputs = default_info.default_runfiles.files,
        outputs = [out_dir],
        command = """
mkdir -p {out_dir}/{name}.runfiles
cp {executable} {out_dir}/{name}
""".format(
            name = name,
            out_dir = out_dir.path,
            executable = executable.path,
        ) + "\n".join([
            """
mkdir -p $(dirname {out_dir}/{name}.runfiles/{rlocationpath})
cp {path} {out_dir}/{name}.runfiles/{rlocationpath}
""".format(
                name = name,
                out_dir = out_dir.path,
                path = f.path,
                rlocationpath = _rlocationpath(ctx, f),
            )
            for f in default_info.default_runfiles.files.to_list()
        ]),
    )

    return [
        DefaultInfo(files = depset([out_dir])),
    ]

def _rlocationpath(ctx, f):
    if f.short_path.startswith("../"):
        return f.short_path[3:]
    else:
        return ctx.workspace_name + "/" + f.short_path

runfiles_dir = rule(
    implementation = _runfiles_dir_impl,
    attrs = {
        "executable": attr.label(
            cfg = "target",
            executable = True,
        ),
    },
)
