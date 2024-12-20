load(":setting.bzl", "validate_and_get_attr_name")
load(":utils.bzl", "is_label", "is_string")

visibility("private")

def make_transition(*, operations, original_settings_label):
    keys = [_get_settings_key(setting) for setting in operations]
    if original_settings_label:
        keys.append(str(original_settings_label))
    implementation = _make_transition_impl(
        operations = operations,
        original_settings_label = original_settings_label,
    )
    return transition(
        implementation = implementation,
        inputs = keys,
        outputs = keys,
    )

def _make_transition_impl(*, operations, original_settings_label):
    return lambda settings, attr: _transition_base_impl(
        settings,
        attr,
        operations = operations,
        original_settings_label = original_settings_label,
    )

def _transition_base_impl(settings, attr, *, operations, original_settings_label):
    # internal_only_reset may be missing if this transition is attached to an extended rule rather
    # than a transitioning alias.
    if original_settings_label and getattr(attr, "internal_only_reset", False):
        original_settings = settings[str(original_settings_label)]
        if original_settings:
            # The reset rule is used in the transitive closure of the transitioning rule. Reset the
            # settings to the recorded original values.
            return json.decode(original_settings)
        else:
            # The reset rule is used in the untransitioned (e.g. the top-level) configuration. We do
            # not want to force users to tag the reset rule target as "manual", so we just make the
            # transition a no-op.
            return {}

    new_settings = {}
    for setting, operation in operations.items():
        attr_name = validate_and_get_attr_name(setting)
        key = _get_settings_key(setting)
        if operation == "set":
            # Always idempotent.
            new_settings[key] = getattr(attr, attr_name)
        elif operation == "extend":
            # Ensure idempotency by appending the tail only when the list-valued setting doesn't
            # already has the tail. This ensures that chaining transitioned rules doesn't result in
            # a blow-up of the list.
            tail = getattr(attr, attr_name)
            if settings[key][-len(tail):] == tail:
                new_settings[key] = settings[key]
            else:
                new_settings[key] = settings[key] + tail
        else:
            fail("Unknown operation: {}".format(operation))

    if original_settings_label:
        original_settings_label_str = str(original_settings_label)
        original_settings = settings[original_settings_label_str]

        if original_settings:
            # If the transitioning rule is used again in the transitive closure, we distinguish
            # between two cases:
            # * The non-original settings do not change (e.g. if a java_21_library directly depends
            #   on another java_21_library). In this case we want the new transition to be a no-op,
            #   preserving the original settings as they are.
            # * The non-original settings do change (e.g. if a java_21_library transitively depends
            #   on another java_21_library with an unrelated transition on java_runtime_version in
            #   the middle). We conservatively choose to fail in this situation as it is unclear how
            #   we should update the original settings.
            real_settings = {k: v for k, v in settings.items() if k != original_settings_label_str}
            if real_settings == new_settings:
                new_settings[original_settings_label_str] = original_settings
            else:
                fail(
                    ("Cannot transition {} to {} because the original settings are not empty: {}." +
                     "Using a rule produced with with_cfg in the transitive closure of another " +
                     "such rule with a further transition between them is currently not " +
                     "supported. Please file an issue at https://github.com/fmeum/with_cfg.bzl " +
                     "to explain your use case.").format(
                        real_settings,
                        new_settings,
                        original_settings,
                    ),
                )

        else:
            new_settings[str(original_settings_label)] = _encode_settings(settings)

    return new_settings

def _get_settings_key(setting):
    if is_label(setting):
        return str(setting)
    elif is_string(setting):
        return "//command_line_option:" + setting
    else:
        fail("Expected Label or string, got: {} ({})".format(setting, type(setting)))

_STARLARK_TYPES = {
    type(t): None
    for t in [True, "", 0, 0.0, []]
}

def _encode_settings(settings):
    # Certain setting values supplied by Bazel are special StarlarkValue types and thus unsupported
    # by json.encode. We work around this by converting everything that isn't a native Starlark type
    # to a string.
    fixed_settings = {
        k: v if type(v) in _STARLARK_TYPES else str(v)
        for k, v in settings.items()
    }
    return json.encode(fixed_settings)
