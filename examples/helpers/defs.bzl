def _untransitioned_target_impl(ctx):
    if "-ST-" in ctx.bin_dir.path:
        fail("This target has been subject to a transition: " + ctx.bin_dir.path)

untransitioned_target = rule(
    implementation = _untransitioned_target_impl,
    doc = "A no-op rule that fails if its configuration has been modified by a transition.",
)
