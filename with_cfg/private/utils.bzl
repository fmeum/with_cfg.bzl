visibility("private")

def is_bool(value):
    return type(value) == _BOOL_TYPE

def is_label(value):
    return type(value) == _LABEL_TYPE

def is_string(value):
    return type(value) == _STRING_TYPE

_BOOL_TYPE = type(True)
_LABEL_TYPE = type(Label("//:bogus"))
_STRING_TYPE = type("")
