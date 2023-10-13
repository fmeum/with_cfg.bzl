load(":setting.bzl", "validate_and_get_attr_name")
load(":frontend.bzl", "get_frontend")
load(":transition.bzl", "make_transition")
load(":transitioning_alias.bzl", "make_transitioning_alias")
load(":utils.bzl", "is_label")
load(":wrapper.bzl", "make_wrapper")

visibility("private")

# buildifier: disable=uninitialized
# buildifier: disable=unnamed-macro
def make_builder(rule_info):
    values = {}
    operations = {}
    mutable_original_settings_label = []
    attrs_to_reset = []

    self = struct(
        build = lambda: _build(
            rule_info = rule_info,
            values = values,
            operations = operations,
            mutable_original_settings_label = mutable_original_settings_label,
            attrs_to_reset = attrs_to_reset,
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
        resettable = lambda label: _resettable(
            label,
            self = self,
            mutable_original_settings_label = mutable_original_settings_label,
        ),
        reset_on_attrs = lambda *attrs: _reset_on_attrs(
            attrs,
            self = self,
            attrs_to_reset = attrs_to_reset,
        ),
    )
    return self

def _build(*, rule_info, values, operations, mutable_original_settings_label, attrs_to_reset):
    if mutable_original_settings_label:
        original_settings_label = mutable_original_settings_label[0]
    else:
        original_settings_label = None

    if attrs_to_reset and not original_settings_label:
        fail("reset_on_attrs() can only be used together with resettable()")

    transition = make_transition(
        operations = operations,
        original_settings_label = original_settings_label,
    )
    transitioning_alias = make_transitioning_alias(
        providers = rule_info.providers,
        transition = transition,
        values = values,
        original_settings_label = original_settings_label,
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
        original_settings_label = original_settings_label,
        attrs_to_reset = attrs_to_reset,
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

def _resettable(label, *, self, mutable_original_settings_label):
    if mutable_original_settings_label:
        fail("resettable() can only be called once")
    if not is_label(label):
        fail("resettable() must be called with a Label(...) of an 'original_settings` target")
    mutable_original_settings_label.append(label)
    return self

def _reset_on_attrs(attrs, *, self, attrs_to_reset):
    if not attrs:
        fail("reset_on_attrs() must be called with at least one attribute name")
    if attrs_to_reset:
        fail("reset_on_attrs() can only be called once")
    attrs_to_reset.extend(attrs)
    return self
