load(":utils.bzl", "is_select")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

def _map_selected(func, branches):
    return {_condition(key): func(value) for key, value in branches.items()}

def map_attr(func, attribute):
    if not is_select(attribute):
        return func(attribute)
    return map_parsed_select(func, attribute)

def _condition(key):
    # type: (Scalar) -> str | Label
    if type(key) == "string" or type(key) == "Label":
        return key
    fail("Expected a select condition, got {}".format(key))

def map_parsed_select(func, value):
    items = [
        (True, _map_selected(func, item[1])) if item[0] == True else (False, func(item[1]))
        for item in decompose_select_elements(value)
    ]  # type: list[_Piece[R, dict[str | Label, R]]]

    # The first selected branch fixes the operator Bazel uses for the whole value.
    anchor = None
    for index, item in enumerate(items):
        if item[0] == True:
            anchor = (index, item[1])
            break
    if anchor == None:
        fail("Expected a select")
    index, branches = anchor
    result = select(branches)
    use_union = type(branches.values()[0]) == "dict"

    def join(result, part, prepend):
        # type: (select[R], R | select[R], bool) -> select[R]
        # Bazel chooses the operator from the first branch. Its kind is known only
        # after decoding the select; the type of each individual piece is a union.
        if use_union:
            return part | result if prepend else result | part  # ty: ignore[unsupported-operator, unsound-return-statement, non-static-type]
        return part + result if prepend else result + part  # ty: ignore[unsupported-operator, unsound-return-statement, non-static-type]

    for piece in reversed(items[:index]):
        if piece[0] == False:
            result = join(result, piece[1], True)
    for piece in items[index + 1:]:
        part = select(piece[1]) if piece[0] == True else piece[1]
        result = join(result, part, False)
    return result

def decompose_select_elements(value):
    # type: (object) -> list[_SelectPiece]
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

def _consume_compound_value(r, pos):
    # type: (str, int) -> tuple[CompoundValue, int]
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
    # type: (str, int) -> tuple[ListOrScalar, int]
    c = r[pos]
    if c == "[":
        return consume_list(r, pos)
    else:
        return consume_single_value(r, pos)

def consume_list(r, pos):
    # type: (str, int) -> tuple[list[Scalar], int]
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
    # type: (str, int) -> tuple[Scalar, int]
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
        for _ in range(start, len(r)):
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
    # type: (str, int) -> tuple[str, int]
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
