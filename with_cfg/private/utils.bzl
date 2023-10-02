visibility("private")

def is_bool(value):
    return type(value) == _BOOL_TYPE

def is_dict(value):
    return type(value) == _DICT_TYPE

def is_int(value):
    return type(value) == _INT_TYPE

def is_label(value):
    return type(value) == _LABEL_TYPE

def is_list(value):
    return type(value) == _LIST_TYPE

def is_select(value):
    return type(value) == _SELECT_TYPE

def is_string(value):
    return type(value) == _STRING_TYPE

_BOOL_TYPE = type(True)
_DICT_TYPE = type({})
_INT_TYPE = type(1)
_LABEL_TYPE = type(Label("//:bogus"))
_LIST_TYPE = type([])
_SELECT_TYPE = type(select({"//conditions:default": []}))
_STRING_TYPE = type("")
