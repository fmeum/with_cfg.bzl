load(":utils.bzl", "is_bool", "is_label", "is_string")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

def validate_and_get_attr_name(setting):
    if is_label(setting):
        # Trigger an early error if the label refers to an invalid repo name.
        # buildifier: disable=no-effect
        setting.workspace_name

        # Ensure that the hash, which is a (signed) 32-bit integer, is non-negative, so that it does
        # not contain a dash, which is not allowed in attribute names. Also ensure that the
        # attribute name starts with a letter as it needs to be a valid identifier.
        return "s_{}_{}".format(hash(str(setting)) + 2147483648, setting.name)
    elif is_string(setting):
        if not setting:
            fail("The empty string is not a valid setting")
        if setting[0] in "@/:":
            fail("Use Label({}) rather than a string to refer to a custom build setting".format(repr(setting)))
        return setting
    else:
        fail("Expected setting to be a Label or a string, got: {} ({})".format(repr(setting), type(setting)))

def get_attr_type(value):
    if is_string(value):
        return "string"
    if is_label(value):
        return "label"
    if is_bool(value):
        return "bool"

    s = str(value)
    pos = 0

    # In a select, skip over the first key to the first value.
    if s.startswith("select({", pos):
        pos += len("select({")
        if s.startswith("Label(", pos):
            pos += len("Label(")

        # Skip over the string.
        if s[pos] != "\"":
            fail("Failed to parse select value: {}".format(s))
        pos += 1
        for _ in range(pos, len(s)):
            c = s[pos]
            pos += 1
            if c == "\\":
                # Skip over the escaped character.
                pos += 1
            elif c == "\"":
                break

        if s.startswith("): ", pos):
            pos += len("): ")
        elif s.startswith(": ", pos):
            pos += len(") ")

    suffix = ""
    if s[pos] == "[":
        pos += 1
        suffix = "_list"

    if s.startswith("Label(", pos):
        return "label" + suffix
    if s[pos] == "\"":
        return "string" + suffix
    if s[pos] == "-" or s[pos].isdigit():
        return "int" + suffix
    if s.startswith("True", pos) and not s[pos + len("True")].isalnum() and not suffix:
        return "bool"
    if s.startswith("False", pos) and not s[pos + len("False")].isalnum() and not suffix:
        return "bool"

    fail("Failed to determine type of: {}".format(s))
