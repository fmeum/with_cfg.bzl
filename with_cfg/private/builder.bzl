load("@bazel_features//:features.bzl", "bazel_features")
load(":extend.bzl", "make_transitioned_rule")
load(":frontend.bzl", "get_frontend")
load(":select.bzl", "map_attr")
load(":setting.bzl", "validate_and_get_attr_name")
load(":transition.bzl", "make_transition")
load(":transitioning_alias.bzl", "make_transitioning_alias")
load(":utils.bzl", "is_label", "is_list")
load(":wrapper.bzl", "make_wrapper")

visibility("private")

# buildifier: disable=unnamed-macro
def make_builder(rule_info):
    return _make_builder(rule_info)

# buildifier: disable=uninitialized
def _make_builder(rule_info, *, values = {}, operations = {}):
    values = dict(values)
    operations = dict(operations)
    mutable_has_been_built = [False]
    mutable_original_settings_label = []
    attrs_to_reset = []
    overrides_allowed = {k: None for k in values}

    self = struct(
        build = lambda: _build(
            rule_info = rule_info,
            values = values,
            operations = operations,
            mutable_has_been_built = mutable_has_been_built,
            mutable_original_settings_label = mutable_original_settings_label,
            attrs_to_reset = attrs_to_reset,
        ),
        extend = lambda setting, value: _extend(
            setting,
            value,
            self = self,
            values = values,
            operations = operations,
            mutable_has_been_built = mutable_has_been_built,
            overrides_allowed = overrides_allowed,
        ),
        set = lambda setting, value: _set(
            setting,
            value,
            self = self,
            values = values,
            operations = operations,
            mutable_has_been_built = mutable_has_been_built,
            overrides_allowed = overrides_allowed,
        ),
        resettable = lambda label: _resettable(
            label,
            self = self,
            mutable_original_settings_label = mutable_original_settings_label,
            mutable_has_been_built = mutable_has_been_built,
        ),
        reset_on_attrs = lambda *attrs: _reset_on_attrs(
            attrs,
            self = self,
            attrs_to_reset = attrs_to_reset,
            mutable_has_been_built = mutable_has_been_built,
        ),
        clone = lambda: _clone(
            rule_info = rule_info,
            values = values,
            operations = operations,
        ),
    )
    return self

def _build(*, rule_info, values, operations, mutable_has_been_built, mutable_original_settings_label, attrs_to_reset):
    if mutable_has_been_built[0]:
        fail("build() can only be called once")
    mutable_has_been_built[0] = True

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

    # Resetting attributes is not yet supported with the extended rule approach.
    if bazel_features.rules.rule_extension_apis_available and rule_info.supports_extension and not attrs_to_reset:
        transitioned_rule = make_transitioned_rule(
            rule_info = rule_info,
            transition = transition,
            values = values,
        )
        if original_settings_label:
            transitioning_alias = make_transitioning_alias(
                providers = rule_info.providers,
                transition = transition,
                values = values,
                original_settings_label = original_settings_label,
            )
            return transitioned_rule, transitioning_alias
        return transitioned_rule, None

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

def _extend(setting, value, *, self, values, operations, mutable_has_been_built, overrides_allowed):
    if mutable_has_been_built[0]:
        fail("extend() can only be called before build()")
    validate_and_get_attr_name(setting)
    if setting in values:
        if setting in overrides_allowed:
            overrides_allowed.pop(setting)
        else:
            fail("Cannot extend setting '{}' because it has already been added to this builder (consider using clone())".format(setting))

    # Make a deep copy so that subsequent modification doesn't affect the builder state.
    # This improves readability but is also necessary for clone() to work correctly.
    values[setting] = map_attr(_clone_value_deeply, value)
    operations[setting] = "extend"
    return self

def _set(setting, value, *, self, values, operations, mutable_has_been_built, overrides_allowed):
    if mutable_has_been_built[0]:
        fail("set() can only be called before build()")
    validate_and_get_attr_name(setting)
    if setting in values:
        if setting in overrides_allowed:
            overrides_allowed.pop(setting)
        else:
            fail("Cannot set setting '{}' because it has already been added to this builder (consider using clone())".format(setting))

    # Make a deep copy so that subsequent modification doesn't affect the builder state.
    # This improves readability but is also necessary for clone() to work correctly.
    values[setting] = map_attr(_clone_value_deeply, value)
    operations[setting] = "set"
    return self

def _resettable(label, *, self, mutable_original_settings_label, mutable_has_been_built):
    if mutable_has_been_built[0]:
        fail("resettable() can only be called before build()")
    if mutable_original_settings_label:
        fail("resettable() can only be called once")
    if not is_label(label):
        fail("resettable() must be called with a Label(...) of an 'original_settings` target")
    mutable_original_settings_label.append(label)
    return self

def _reset_on_attrs(attrs, *, self, attrs_to_reset, mutable_has_been_built):
    if mutable_has_been_built[0]:
        fail("reset_on_attrs() can only be called before build()")
    if not attrs:
        fail("reset_on_attrs() must be called with at least one attribute name")
    if attrs_to_reset:
        fail("reset_on_attrs() can only be called once")
    attrs_to_reset.extend(attrs)
    return self

def _clone(*, rule_info, values, operations):
    return _make_builder(rule_info, values = values, operations = operations)

def _clone_value_deeply(value):
    # We only support valid types for settings values.
    if is_list(value):
        return list(value)

    # All other valid types are immutable.
    return value
