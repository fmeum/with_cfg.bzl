load(":setting.bzl", "get_rule_attrs", "validate_and_get_internal_attr_name")

visibility("private")

def make_transitioned_rule(*, rule_info, transition, operations, values):
    return rule(
        implementation = _transitioned_rule_impl,
        parent = rule_info.kind,
        cfg = transition,
        initializer = lambda **kwargs: _initializer_base(kwargs = kwargs, values = values),
        attrs = get_rule_attrs(operations = operations, values = values),
    )

def _transitioned_rule_impl(ctx):
    return ctx.super()

def _initializer_base(*, kwargs, values):
    return kwargs | {
        validate_and_get_internal_attr_name(setting): value
        for setting, value in values.items()
    }
