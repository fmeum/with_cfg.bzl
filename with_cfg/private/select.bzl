load(":utils.bzl", "is_dict", "is_select")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

def map_attr(func, attribute):
    if not is_select(attribute):
        return func(attribute)

    return compose_select_value([
        _apply_func(func, item)
        for item in decompose_select_elements(attribute)
    ])

def _apply_func(func, item):
    in_select, element = item
    if in_select:
        return (True, {
            k: func(v)
            for k, v in element.items()
        })
    else:
        return (False, func(element))

def decompose_select_elements(value):
    r = repr(value)
    pos = 0
    items = []
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
        else:
            element, pos = _consume_compound_value(r, pos)

        items.append((in_select, element))

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

def compose_select_value(items):
    # Determine combinator for select items in a first pass.
    # This is always `+=` unless the select contains dicts, in which case it is
    # `|=`.
    combine_as_dict = any([_is_dict_element(item) for item in items])
    parts = [
        select(element) if in_select else element
        for in_select, element in items
    ]
    result = parts[0]
    for part in parts[1:]:
        if combine_as_dict:
            result |= part
        else:
            result += part
    return result

def _is_dict_element(item):
    in_select, element = item
    if in_select:
        return any([is_dict(value) for value in element.values()])
    else:
        return is_dict(element)

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
