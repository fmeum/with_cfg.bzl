load(":setting.bzl", "validate_and_get_attr_name")
load(":utils.bzl", "is_label", "is_string")

visibility("private")

def make_transition(*, operations):
    keys = [_get_settings_key(setting) for setting in operations]
    return transition(
        implementation = _make_transition_impl(operations),
        inputs = keys,
        outputs = keys,
    )

def _make_transition_impl(operations):
    return lambda settings, attr: _transition_base_impl(settings, attr, operations = operations)

def _transition_base_impl(settings, attr, *, operations):
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
    return new_settings

def _get_settings_key(setting):
    if is_label(setting):
        return str(setting)
    elif is_string(setting):
        return "//command_line_option:" + setting
    else:
        fail("Expected Label or string, got: {} ({})".format(setting, type(setting)))
