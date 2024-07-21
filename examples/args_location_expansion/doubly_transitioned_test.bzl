load("@with_cfg.bzl", "with_cfg")
load("//args_location_expansion/rules:defs.bzl", "transitioned_test")

_builder = with_cfg(transitioned_test)
_builder.set(Label("//args_location_expansion/rules:with_cfg_setting"), "with_cfg")
doubly_transitioned_test, _doubly_transitioned_test_ = _builder.build()
