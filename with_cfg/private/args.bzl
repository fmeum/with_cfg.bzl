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
