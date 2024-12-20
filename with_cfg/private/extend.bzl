load(":setting.bzl", "get_attr_type", "validate_and_get_attr_name")

visibility("private")

def make_transitioned_rule(*, rule_info, transition, values):
    settings_attrs = {
        validate_and_get_attr_name(setting): getattr(attr, get_attr_type(value))()
        for setting, value in values.items()
    }
    return rule(
        implementation = _transitioned_rule_impl,
        parent = rule_info.kind,
        cfg = transition,
        initializer = lambda **kwargs: _initializer_base(kwargs = kwargs, values = values),
        attrs = settings_attrs,
    )

def _transitioned_rule_impl(ctx):
    return ctx.super()

def _initializer_base(*, kwargs, values):
    return kwargs | {
        validate_and_get_attr_name(setting): value
        for setting, value in values.items()
    }
