load(":utils.bzl", "is_dict", "is_select")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

# Repr decoding cannot prove the callback's original input type.
def map_attr(func, attribute):  # ty: ignore[missing-parameter-annotation]
    return _map_attr(func, attribute, _map_selected, compose_select_value)

def _map_selected(func, branches):
    return {_condition(key): func(value) for key, value in branches.items()}

def _map_attr(func, attribute, map_selected, compose):
    if not is_select(attribute):
        return func(attribute)
    return compose([
        (True, map_selected(func, item[1])) if item[0] == True else (False, func(item[1]))
        for item in decompose_select_elements(attribute)
    ])

def map_string_list_attr(func, attribute):
    return _map_attr(func, attribute, _map_list_selected, _compose_list)

def map_dict_attr(func, attribute):
    return _map_attr(func, attribute, _map_dict_selected, _compose_dict)

def _map_dict_selected(func, branches):
    return select(_map_selected(func, branches))

def _compose_dict(items):
    return _compose(items, lambda item: item[1], lambda _anchor, left, right: left | right)

def _condition(key):
    if type(key) == "string" or type(key) == "Label":
        return key
    fail("Expected a select condition, got {}".format(key))

def _map_list_selected(func, branches):
    # Bazel derives the selector kind from its first branch. Seed that branch
    # before mapping the rest; setdefault preserves it even for an unknown key.
    pairs = branches.items()
    first_pair = pairs[0]
    key = _condition(first_pair[0])
    first = func(first_pair[1])
    if first == None:
        mapped = {}  # type: dict[str | Label, list[str] | None]
        mapped[key] = first
        for later_key, later_value in pairs[1:]:
            mapped.setdefault(_condition(later_key), func(later_value))
        return ("none", select(mapped))
    else:
        mapped = {}  # type: dict[str | Label, list[str] | None]
        mapped[key] = first
        for later_key, later_value in pairs[1:]:
            mapped.setdefault(_condition(later_key), func(later_value))
        return ("list", select(mapped))

def _list_value(item):
    if item[0] == True:
        return item[1]
    value = item[1]
    return ("none", None) if value == None else ("list", value)

def _combine_list(_anchor, left, right):
    if left[0] == "list" and right[0] == "list":
        return ("list", left[1] + right[1])
    if left[0] == "none" and right[0] == "none":
        left_value = left[1]
        right_value = right[1]
        if left_value == None:
            if right_value == None:
                fail("Cannot add two plain None values")
            return ("none", left_value + right_value)
        return ("none", left_value + right_value)
    fail("Cannot combine list and None selectors")

def _compose_list(items):
    return _compose(items, _list_value, _combine_list)[1]

def decompose_select_elements(value):
    r = repr(value)
    pos = 0
    items = []  # type: list[_SelectPiece]
    in_select = False
    for _ in range(len(r)):
        c = r[pos]
        if c == "s":
            # Skip over `select(`.
            pos += 7
            in_select = True

        # An inlined version of _consume_compound_value to handle dicts in dicts
        # as they appear in selects. This is necessary because Starlark doesn't
        # permit recursion.
        if in_select or c == "{":
            # Skip over `{`.
            pos += 1
            element = {}
            for _ in range(len(r)):
                c = r[pos]
                if c == "}":
                    pos += 1
                    break
                elif c == ",":
                    # Skip over `, `.
                    pos += 2
                key, pos = consume_single_value(r, pos)

                # Skip over `: `.
                pos += 2
                value, pos = _consume_compound_value(r, pos)
                element[key] = value
            items.append((True, element) if in_select else (False, element))
        else:
            element, pos = _consume_compound_value(r, pos)
            items.append((False, element))

        if in_select:
            # Skip over `)`.
            pos += 1
            in_select = False

        if pos >= len(r):
            return items
        else:
            # Skip over ` + `
            pos += 3

    fail("Failed to parse '{}'".format(r))

# Composition depends on the first mapped branch's runtime selector kind.
def compose_select_value(items):  # ty: ignore[missing-parameter-annotation]
    return _compose(
        items,
        lambda item: (is_dict(item[1].values()[0]), select(item[1])) if item[0] == True else (is_dict(item[1]), item[1]),
        lambda anchor, left, right: (anchor[0], left[1] | right[1] if anchor[0] else left[1] + right[1]),
    )[1]

def _compose(items, embed, combine):
    # Start at a select so nullable prefixes never require None + None.
    first_select = 0
    for i, (in_select, _) in enumerate(items):
        if in_select:
            first_select = i
            break

    # The anchor chooses the operator for every prefix and suffix combination.
    anchor = embed(items[first_select])
    result = anchor
    for item in reversed(items[:first_select]):
        result = combine(anchor, embed(item), result)
    for item in items[first_select + 1:]:
        result = combine(anchor, result, embed(item))
    return result

def _consume_compound_value(r, pos):
    c = r[pos]
    if c == "{":
        # Skip over `{`.
        pos += 1
        d = {}
        for _ in range(len(r)):
            c = r[pos]
            if c == "}":
                pos += 1
                break
            elif c == ",":
                # Skip over `, `.
                pos += 2
            key, pos = consume_single_value(r, pos)

            # Skip over `: `.
            pos += 2
            value, pos = _consume_list_or_single_value(r, pos)
            d[key] = value
        return d, pos
    else:
        return _consume_list_or_single_value(r, pos)

def _consume_list_or_single_value(r, pos):
    c = r[pos]
    if c == "[":
        return consume_list(r, pos)
    else:
        return consume_single_value(r, pos)

def consume_list(r, pos):
    """Consume the rest of a list of single values if positioned at the opening bracket.

    Args:
      r: The string to parse.
      pos: The position of the opening bracket.

    Returns:
      A tuple of the list and the position after the closing bracket.
    """
    list = []
    pos += 1
    for _ in range(len(r)):
        c = r[pos]
        if c == "]":
            return list, pos + 1
        elif c == ",":
            # Skip over `, `
            pos += 2
        else:
            element, pos = consume_single_value(r, pos)
            list.append(element)
    fail("Should not have been reached while parsing list literal in: " + r)

def consume_single_value(r, pos):
    c = r[pos]
    if c == "\"":
        return _consume_string(r, pos)
    elif c == "F":
        return False, pos + 5
    elif c == "T":
        return True, pos + 4
    elif c == "N":
        return None, pos + 4
    elif c == "L":
        # Skip over `Label(`.
        pos += 6
        string, after_string = _consume_string(r, pos)

        # Labels in the main repository are not prefixed with `@` at all since
        # their `repr` implementation doesn't use the unambiguous form as of
        # Bazel 8.
        if not string.startswith("@@"):
            string = "@@" + string

        # Skip over `)`.
        return Label(string), after_string + 1
    elif c == "-" or c.isdigit():
        start = pos
        for _ in range(len(r)):
            c = r[pos]
            if not c.isdigit() and c != "-":
                if c == ".":
                    fail("Floats are not supported: " + r[start:])
                break
            pos += 1
        return int(r[start:pos]), pos
    else:
        fail("Unexpected token at {} in '{}'".format(pos, r))

def _consume_string(r, pos):
    """Consume the rest of a string literal if positioned at the opening quote."""
    chunks = []
    pos += 1
    start = pos
    for _ in range(len(r)):
        if r[pos] == "\\":
            chunks.append(r[start:pos])

            # Skip over backslash
            pos += 1
            real_char = _ESCAPED_TO_REAL_CHAR[r[pos]]
            if real_char != None:
                chunks.append(real_char)
                pos += 1
            else:
                # The only remaining alternative is a hex escape.
                # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/net/starlark/java/eval/Printer.java;l=239-259;drc=9bf8f396db5c8b204c61b34638ca15ece0328fc0
                # Skip over "xff".
                pos += 3
                real_char = _HEX_ESCAPED_TO_REAL_CHAR[r[pos - 2:pos]]
                chunks.append(real_char)
            start = pos
        elif r[pos] == "\"":
            chunks.append(r[start:pos])
            return "".join(chunks), pos + 1
        else:
            pos += 1
    fail("Should not have been reached while parsing string literal in: " + r)

_ESCAPED_TO_REAL_CHAR = {
    "\"": "\"",
    "\\": "\\",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    # Sentinel value for handling \xff escapes without using get().
    "x": None,
}

# Map hex digits of \xxx escapes to their octal string representation.
_HEX_ESCAPED_TO_REAL_CHAR = {
    "00": "\0",
    "01": "\1",
    "02": "\2",
    "03": "\3",
    "04": "\4",
    "05": "\5",
    "06": "\6",
    "07": "\7",
    "08": "\10",
    "09": "\11",
    "0a": "\12",
    "0b": "\13",
    "0c": "\14",
    "0d": "\15",
    "0e": "\16",
    "0f": "\17",
    "10": "\20",
    "11": "\21",
    "12": "\22",
    "13": "\23",
    "14": "\24",
    "15": "\25",
    "16": "\26",
    "17": "\27",
    "18": "\30",
    "19": "\31",
    "1a": "\32",
    "1b": "\33",
    "1c": "\34",
    "1d": "\35",
    "1e": "\36",
    "1f": "\37",
}
