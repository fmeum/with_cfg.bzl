load(":rewrite.bzl", "make_label_rewriter", "rewrite_locations_in_attr")
load(":setting.bzl", "validate_and_get_attr_name")
load(":select.bzl", "map_attr")
load(":utils.bzl", "is_dict", "is_label", "is_list", "is_string")

visibility("private")

# buildifier: disable=unnamed-macro
def make_wrapper(
        *,
        rule_info,
        frontend,
        transitioning_alias,
        values,
        original_settings_label,
        attrs_to_reset):
    return lambda *, name, **kwargs: _wrapper(
        name = name,
        kwargs = kwargs,
        rule_info = rule_info,
        frontend = frontend,
        transitioning_alias = transitioning_alias,
        values = values,
        original_settings_label = original_settings_label,
        attrs_to_reset = attrs_to_reset,
    )

# Attributes common to all rules.
# These attributes are applied to all targets generated by the wrapper.
# testonly, tags and visibility are handled specially.
_COMMON_ATTRS = [
    # keep sorted
    "compatible_with",
    "deprecation",
    "exec_compatible_with",
    "exec_properties",
    "features",
    "restricted_to",
    "target_compatible_with",
    "toolchains",
]

# Attributes common to all executable and test rules.
# These attributes are applied to the original target and the frontend if the original target is
# executable.
# env and env_inherit are covered by the forwarded RunEnvironmentInfo instead.
_EXECUTABLE_ATTRS = [
    # keep sorted
    "args",
]

# Attributes common to all test rules.
# These attributes are applied to the original target and the frontend if the original target is a
# test.
# env and env_inherit are covered by the forwarded RunEnvironmentInfo instead.
_TEST_ATTRS = [
    # keep sorted
    "args",
    "flaky",
    "local",
    "shard_count",
    "size",
    "timeout",
]

def _wrapper(
        *,
        name,
        kwargs,
        rule_info,
        frontend,
        transitioning_alias,
        values,
        original_settings_label,
        attrs_to_reset):
    tags = kwargs.pop("tags", None)
    if not tags:
        tags_with_manual = ["manual"]
    elif "manual" not in tags:
        tags_with_manual = tags + ["manual"]
    else:
        tags_with_manual = tags

    visibility = kwargs.pop("visibility", None)
    common_attrs = {
        attr: kwargs.pop(attr)
        for attr in _COMMON_ATTRS
        if attr in kwargs
    }

    # Due to --trim_test_configuration, all targets that depend on tests (such as our
    # transitioning_alias) must be marked as testonly to avoid action conflicts.
    if rule_info.test:
        common_attrs["testonly"] = True
    elif "testonly" in kwargs:
        common_attrs["testonly"] = kwargs.pop("testonly")

    if rule_info.test:
        extra_attrs = {
            attr: kwargs.pop(attr)
            for attr in _TEST_ATTRS
            if attr in kwargs
        }
    elif rule_info.executable:
        extra_attrs = {
            attr: kwargs.pop(attr)
            for attr in _EXECUTABLE_ATTRS
            if attr in kwargs
        }
    else:
        extra_attrs = {}

    # Native rules use magic "env" and "env_inherit" attributes to set environment variables. We
    # have to implement these attributes manually as they aren't forwarded via RunEnvironmentInfo.
    if rule_info.native and (rule_info.executable or rule_info.test):
        if "env" in kwargs:
            extra_attrs["env"] = kwargs.pop("env")
        if "env_inherit" in kwargs:
            extra_attrs["env_inherit"] = kwargs.pop("env_inherit")

    dirname, separator, basename = name.rpartition("/")
    original_name = "{dirname}{separator}{basename}_/{basename}".format(
        dirname = dirname,
        separator = separator,
        basename = basename,
    )
    alias_name = name + "_with_cfg"

    processed_kwargs = _process_attrs_for_reset(
        attrs = kwargs,
        attrs_to_reset = attrs_to_reset,
        reset_target = lambda *, name, exports: transitioning_alias(
            name = name,
            exports = exports,
            tags = ["manual"],
            visibility = ["//visibility:private"],
        ),
        basename = basename,
    )
    rule_info.kind(
        name = original_name,
        tags = tags_with_manual,
        visibility = ["//visibility:private"],
        **(processed_kwargs | common_attrs | extra_attrs)
    )

    alias_attrs = {
        validate_and_get_attr_name(setting): value
        for setting, value in values.items()
    }
    if original_settings_label:
        alias_attrs["internal_only_reset"] = False

    transitioning_alias(
        name = alias_name,
        exports = ":" + original_name,
        tags = tags_with_manual,
        visibility = ["//visibility:private"],
        **(alias_attrs | common_attrs)
    )

    frontend(
        name = name,
        exports = ":" + alias_name,
        tags = tags,
        visibility = visibility,
        **(common_attrs | extra_attrs)
    )

    for implicit_target in rule_info.implicit_targets:
        dirprefix = dirname + separator
        sub_name = implicit_target.format(
            dirprefix = dirprefix,
            basename = basename,
            name = dirprefix + basename,
        )
        original_dirprefix = dirprefix + basename + "_/"
        original_sub_name = implicit_target.format(
            dirprefix = original_dirprefix,
            basename = basename,
            name = original_dirprefix + basename,
        )
        transitioning_alias(
            name = sub_name,
            exports = ":" + original_sub_name,
            tags = tags_with_manual,
            visibility = visibility,
            **(alias_attrs | common_attrs)
        )

def _process_attrs_for_reset(*, attrs, attrs_to_reset, reset_target, basename):
    if not attrs_to_reset:
        return attrs

    # In a first pass over only the attributes to reset, replace all labels representing
    # dependencies with labels of a `reset_target` target that forwards the dep's providers while
    # applying the reset transition. Along the way collect a map of original to new labels.
    label_map = {}
    first_pass_attrs = dict(attrs)
    for attr in attrs_to_reset:
        if not attr in attrs:
            continue
        mutable_num_calls = [0]
        attr_func = lambda dep: _replace_dep_attr(
            dep = dep,
            label_map = label_map,
            reset_target = reset_target,
            base_target_name = basename + "__" + attr,
            mutable_num_calls = mutable_num_calls,
        )
        first_pass_attrs[attr] = map_attr(attr_func, attrs[attr])

    # In a second pass, now over all attributes, rewrite all $(location ...) expressions. These can
    # even appear in attributes that are reset (as values in attr.label_keyed_string_dict).
    second_pass_attrs = {}
    label_rewriter = make_label_rewriter(label_map)
    for attr, value in first_pass_attrs.items():
        second_pass_attrs[attr] = rewrite_locations_in_attr(value, label_rewriter)

    return second_pass_attrs

def _replace_dep_attr(*, dep, label_map, reset_target, base_target_name, mutable_num_calls):
    if is_list(dep):
        # attr.label_list
        result = [
            _replace_single_dep(
                label_string = label_string,
                label_map = label_map,
                reset_target = reset_target,
                base_target_name = base_target_name,
                mutable_num_calls = mutable_num_calls,
            )
            for label_string in dep
        ]
    elif is_dict(dep):
        # attr.label_keyed_string_dict (only the keys represent deps)
        result = {
            _replace_single_dep(
                label_string = label_string,
                label_map = label_map,
                reset_target = reset_target,
                base_target_name = base_target_name,
                mutable_num_calls = mutable_num_calls,
            ): v
            for label_string, v in dep.items()
        }
    else:
        # attr.label
        result = _replace_single_dep(
            label_string = dep,
            label_map = label_map,
            reset_target = reset_target,
            base_target_name = base_target_name,
            mutable_num_calls = mutable_num_calls,
        )

    mutable_num_calls[0] += 1
    return result

def _replace_single_dep(
        *,
        label_string,
        label_map,
        reset_target,
        base_target_name,
        mutable_num_calls):
    use_label = is_label(label_string)
    if not use_label and not is_string(label_string):
        fail("Expected dependency, got '{}' of type {}".format(label_string, type(label_string)))
    label = native.package_relative_label(label_string)
    if label in label_map:
        target_label_string = label_map[label]
    else:
        # Multiple targets can be referenced in a single logical dep if that dep is a select.
        target_name = base_target_name + "_" + str(mutable_num_calls[0])
        reset_target(
            name = target_name,
            exports = label,
        )
        target_label_string = ":" + target_name
        label_map[label] = target_label_string
    return native.package_relative_label(target_label_string) if use_label else target_label_string
