load("//with_cfg/private:original_settings.bzl", _original_settings = "original_settings")
load("//with_cfg/private:with_cfg.bzl", _with_cfg = "with_cfg")

visibility("//")

with_cfg = _with_cfg
original_settings = _original_settings
