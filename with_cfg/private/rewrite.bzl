load(":select.bzl", "map_attr")
load(":utils.bzl", "is_dict", "is_list", "is_string")

visibility(["//with_cfg/private/...", "//with_cfg/tests/..."])

# buildifier: disable=unnamed-macro
def make_label_rewriter(label_map):
    return lambda label: _label_rewriter_base(label, label_map = label_map)

def _label_rewriter_base(label_string, *, label_map):
    label = native.package_relative_label(label_string)
    rewritten_label = label_map.get(label)
    if not rewritten_label:
        return label_string
    return str(rewritten_label)

def rewrite_locations_in_attr(value, label_rewriter):
    return map_attr(lambda v: _rewrite_locations_in_value(v, label_rewriter), value)

def _rewrite_locations_in_value(value, label_rewriter):
    if not value:
        return value
    if is_dict(value):
        return {
            rewrite_locations_in_single_value(k, label_rewriter): _rewrite_locations_in_list_or_single_value(v, label_rewriter)
            for k, v in value.items()
        }
    return _rewrite_locations_in_list_or_single_value(value, label_rewriter)

def _rewrite_locations_in_list_or_single_value(value, label_rewriter):
    if not value:
        return value
    if is_list(value):
        return [rewrite_locations_in_single_value(v, label_rewriter) for v in value]
    return rewrite_locations_in_single_value(value, label_rewriter)

# Based on:
# https://github.com/bazelbuild/bazel/blob/9bf8f396db5c8b204c61b34638ca15ece0328fc0/src/main/starlark/builtins_bzl/common/cc/cc_helper.bzl#L777C1-L830C27
# SPDX: Apache-2.0
def rewrite_locations_in_single_value(expression, label_rewriter):
    if not is_string(expression):
        return expression
    if "$(" not in expression:
        return expression

    idx = 0
    last_make_var_end = 0
    result = []
    n = len(expression)
    for _ in range(n):
        if idx >= n:
            break
        if expression[idx] != "$":
            idx += 1
            continue

        idx += 1

        # We've met $$ pattern, so $ is escaped.
        if idx < n and expression[idx] == "$":
            idx += 1
            result.append(expression[last_make_var_end:idx])
            last_make_var_end = idx
            # We might have found a potential start for Make Variable.

        elif idx < n and expression[idx] == "(":
            # Try to find the closing parentheses.
            make_var_start = idx
            make_var_end = make_var_start
            for j in range(idx + 1, n):
                if expression[j] == ")":
                    make_var_end = j
                    break

            # Note we cannot go out of string's bounds here,
            # because of this check.
            # If start of the variable is different from the end,
            # we found a make variable.
            if make_var_start != make_var_end:
                # Some clarifications:
                # *****$(MAKE_VAR_1)*******$(MAKE_VAR_2)*****
                #                   ^       ^          ^
                #                   |       |          |
                #   last_make_var_end  make_var_start make_var_end
                result.append(expression[last_make_var_end:make_var_start - 1])
                make_var = expression[make_var_start + 1:make_var_end]
                exp = _rewrite_location(make_var, label_rewriter)
                result.append("$({})".format(exp))

                # Update indexes.
                idx = make_var_end + 1
                last_make_var_end = idx

    # Add the last substring which would be skipped by for loop.
    if last_make_var_end < n:
        result.append(expression[last_make_var_end:n])

    return "".join(result)

def _rewrite_location(expr, label_rewriter):
    type, _, label = expr.partition(" ")
    if not label:
        return expr
    return type + " " + label_rewriter(label)
