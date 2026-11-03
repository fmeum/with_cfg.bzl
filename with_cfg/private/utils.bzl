visibility("private")

def is_bool(value):
    # type: (object) -> bool
    return type(value) == _BOOL_TYPE

def is_dict(value):
    # type: (object) -> bool
    return type(value) == _DICT_TYPE

def is_int(value):
    # type: (object) -> bool
    return type(value) == _INT_TYPE

# TODO(https://github.com/tamird/sty/blob/sty-action-v0.2.0/docs/type-interfaces.md#materialized-types):
# Use native predicate annotations when the checker can narrow a caller’s
# value after a test for a Label, list, select, or string.
def is_label(value):
    # type: (object) -> TypeIs[Label]
    return type(value) == _LABEL_TYPE

def is_list(value):
    # type: (object) -> TypeGuard[Sequence[object]]
    return type(value) == _LIST_TYPE

def is_select(value):
    # type: (object) -> TypeIs[select[object, object]]
    return type(value) == _SELECT_TYPE

def is_string(value):
    # type: (object) -> TypeIs[str]
    return type(value) == _STRING_TYPE

_BOOL_TYPE = type(True)
_DICT_TYPE = type({})
_INT_TYPE = type(1)
_LABEL_TYPE = type(Label("//:bogus"))
_LIST_TYPE = type([])
_SELECT_TYPE = type(select({"//conditions:default": 0}))
_STRING_TYPE = type("")
