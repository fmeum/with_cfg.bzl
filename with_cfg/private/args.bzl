"""
Logic for setting "args" on a transitioned rule with location expansion.

Compared to "env" and "env_inherit", which are backed by a provider, "args"
handling in Bazel is still based on "magic" handling in the core and thus much
more difficult to generically forward. This results in the following
complexities handled by the functions in this file:

1. The way locations expand in "args" depends on the configuration of the
   underlying target, which can be affected by transitions both by with_cfg.bzl
   and the rule itself. We thus need to obtain the expanded locations from the
   rule context instead of e.g. rewriting labels to helper targets during the
   loading phase, which would miss the effect of transitions applied by the rule
   itself.
   We use a non-recursing aspect on the original rule to collect the files
   corresponding to labels mentioned in location expansion in "args" and provide
   them to the frontend rule via output groups named after the user-provided
   label strings. As a consequence, we also have to set the "args" attribute on
   the underlying target so that the aspect can see it - aspect attributes are
   limited to integers and string enums.
2. "args" can only be set at load time via the magic attribute and the only way
   to get analysis time information into it is via the hard-coded location
   expansion applied to it in
   https://github.com/bazelbuild/bazel/blob/9425e365ebf921d4286fcf159b429e38f6b0a48f/src/main/java/com/google/devtools/build/lib/analysis/RunfilesSupport.java#L525
   We create a helper `filegroup` target for each unique label string mentioned
   in a location expansion expression in "args", add it to the (otherwise
   unused) `data` attribute of the frontend and rewrite the label strings to
   instead point to the `filegroup` targets.
3. `native.package_relative_label` is not available in the analysis phase and
   rule or aspect implementation logic can't see the labels of alias targets,
   so the only way to reliably match user-provided labels to the files they
   represent is to query `ctx.expand_location("$(execpaths ...)")` and manually
   collect the files with the given paths.
"""

load(":providers.bzl", "ArgsInfo")
load(":rewrite.bzl", "rewrite_locations_in_attr", "rewrite_locations_in_single_value")

visibility("private")

def rewrite_args(name, args, make_filegroup):
    # type: (string, list[string], Any) -> tuple[list[string], list[Label]]
    seen_labels = {}
    filegroup_labels = []

    def rewrite_label(label_string):
        # type: (string) -> string
        escaped_label = _escape_label(label_string)
        filegroup_name = name + "__args__" + escaped_label
        if label_string not in seen_labels:
            seen_labels[label_string] = None
            make_filegroup(
                name = filegroup_name,
                srcs = [":" + name],
                output_group = _OUTPUT_GROUPS_PREFIX + label_string,
            )
            filegroup_labels.append(native.package_relative_label(filegroup_name))
        return ":" + filegroup_name

    return rewrite_locations_in_attr(args, rewrite_label), filegroup_labels

def _args_aspect_impl(target, ctx):
    # type: (Target, ctx) -> list[Provider]
    if not hasattr(ctx.rule.attr, "args"):
        return []

    execpaths_expansion_to_files = {}
    targets = {}

    # https://github.com/bazelbuild/bazel/blob/af8deb85cbc627a507605e67aa71e829f7db630f/src/main/java/com/google/devtools/build/lib/analysis/LocationExpander.java#L446-L516
    for attr in _LOCATION_EXPANSION_ARGS:
        deps = getattr(ctx.rule.attr, attr, [])
        if type(deps) != type([]):
            continue
        for target in deps:
            default_info = target[DefaultInfo]
            if default_info.files_to_run and default_info.files_to_run.executable:
                files = depset([default_info.files_to_run.executable])
            else:
                files = default_info.files

            # https://github.com/bazelbuild/bazel/blob/af8deb85cbc627a507605e67aa71e829f7db630f/src/main/java/com/google/devtools/build/lib/analysis/LocationExpander.java#L338-L348
            sorted_paths = sorted([_callable_path_string(f) for f in files.to_list()])
            execpaths_expansion = " ".join([_shell_escape(p) for p in sorted_paths])
            execpaths_expansion_to_files[execpaths_expansion] = files
            targets[target] = None

    template_variables = {}
    toolchains = getattr(ctx.rule.attr, "toolchains", [])
    if type(toolchains) == type([]):
        for toolchain in toolchains:
            if platform_common.TemplateVariableInfo in toolchain:
                template_variables.update(
                    toolchain[platform_common.TemplateVariableInfo].variables,
                )

    labels = {}

    def collect_label(label):
        labels[label] = None
        return label

    for arg in ctx.rule.attr.args:
        rewrite_locations_in_single_value(arg, collect_label)

    labels_to_files = {}
    for label in labels.keys():
        execpaths_expansion = ctx.expand_location("$(execpaths {})".format(label), targets = targets.keys())
        labels_to_files[label] = execpaths_expansion_to_files[execpaths_expansion]

    return [
        OutputGroupInfo(**{_OUTPUT_GROUPS_PREFIX + label: f for label, f in labels_to_files.items()}),
        ArgsInfo(template_variable_info = platform_common.TemplateVariableInfo(template_variables)),
    ]

args_aspect = aspect(
    implementation = _args_aspect_impl,
)

_LOCATION_EXPANSION_ARGS = [
    # keep sorted
    "data",
    "deps",
    "implementation_deps",
    "srcs",
    "tools",
]

_OUTPUT_GROUPS_PREFIX = "_with_cfg.bzl_args__"

def _callable_path_string(file):
    # type: (File) -> str
    # https://github.com/bazelbuild/bazel/blob/af8deb85cbc627a507605e67aa71e829f7db630f/src/main/java/com/google/devtools/build/lib/vfs/PathFragment.java#L625-L631
    path = file.path
    if not path:
        return "."
    if not "/" in path:
        return "./" + path
    return path

# Based on
# https://github.com/bazelbuild/bazel/blob/af8deb85cbc627a507605e67aa71e829f7db630f/src/main/starlark/builtins_bzl/common/java/java_helper.bzl#L365-L386
# Modified to handle ~ in the same way as
# https://github.com/bazelbuild/bazel/blob/30f6c8238f39c4a396b3cb56a98c1a2e79d10bb9/src/main/java/com/google/devtools/build/lib/util/ShellEscaper.java#L106-L108
def _shell_escape(s):  # type: (string) -> string
    """Shell-escape a string

    Quotes a word so that it can be used, without further quoting, as an argument
    (or part of an argument) in a shell command.

    Args:
        s: (str) the string to escape

    Returns:
        (str) the shell-escaped string
    """
    if not s:
        # Empty string is a special case: needs to be quoted to ensure that it
        # gets treated as a separate argument.
        return "''"
    must_escape = s.startswith("~")
    for c in s.elems():
        # We do this positively so as to be sure we don't inadvertently forget
        # any unsafe characters.
        if not c.isalnum() and c not in "@%-_+:,./~":
            must_escape = True
            break
    if must_escape:
        return "'" + s.replace("'", "'\\''") + "'"
    else:
        return s

def _escape_label(label_string):  # type: (string) -> string
    # https://github.com/bazelbuild/bazel/blob/af8deb85cbc627a507605e67aa71e829f7db630f/src/main/java/com/google/devtools/build/lib/actions/Actions.java#L375-L381
    return label_string.replace("_", "_U").replace("/", "_S").replace("\\", "_B").replace(":", "_C").replace("@", "_A")
