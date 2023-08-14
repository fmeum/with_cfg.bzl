load(":setting.bzl", "validate_and_get_attr_name")
load(":frontend.bzl", "get_frontend")
load(":transition.bzl", "make_transition")
load(":transitioning_alias.bzl", "make_transitioning_alias")
load(":wrapper.bzl", "make_wrapper")

visibility("private")

# buildifier: disable=uninitialized
def make_builder(rule_info):
    values = {}
    operations = {}

    self = struct(
        build = lambda: _build(
            rule_info = rule_info,
            values = values,
            operations = operations,
        ),
        extend = lambda setting, value: _extend(
            setting,
            value,
            self = self,
            values = values,
            operations = operations,
        ),
        set = lambda setting, value: _set(
            setting,
            value,
            self = self,
            values = values,
            operations = operations,
        ),
    )
    return self

def _build(*, rule_info, values, operations):
    transition = make_transition(operations = operations)
    transitioning_alias = make_transitioning_alias(
        providers = rule_info.providers,
        transition = transition,
        values = values,
    )
    frontend = get_frontend(
        executable = rule_info.executable,
        test = rule_info.test,
    )
    wrapper = make_wrapper(
        rule_info = rule_info,
        frontend = frontend,
        transitioning_alias = transitioning_alias,
        values = values,
    )

    return wrapper, transitioning_alias

def _extend(setting, value, *, self, values, operations):
    validate_and_get_attr_name(setting)
    if setting in values:
        fail("Cannot extend setting '{}' because it has already been added to this builder".format(setting))
    values[setting] = value
    operations[setting] = "extend"
    return self

def _set(setting, value, *, self, values, operations):
    validate_and_get_attr_name(setting)
    if setting in values:
        fail("Cannot set setting '{}' because it has already been added to this builder".format(setting))
    values[setting] = value
    operations[setting] = "set"
    return self
