from __future__ import annotations

from ansible.errors import AnsibleFilterError


def _validate_string_list(value, name):
    if value is None:
        return []

    if not isinstance(value, list):
        raise AnsibleFilterError(f"{name} must be a list of strings")

    for item in value:
        if not isinstance(item, str):
            raise AnsibleFilterError(f"{name} must be a list of strings")

    return value


def _unique(items):
    seen = set()
    result = []

    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)

    return result


def command_flag_keys(args, pair_flags=None):
    argv = _validate_string_list(args, "args")
    pair_flag_set = set(_validate_string_list(pair_flags, "pair_flags"))

    keys = []
    skip_next = False

    for arg in argv:
        if skip_next:
            skip_next = False
            continue

        if arg in pair_flag_set:
            keys.append(arg)
            skip_next = True
            continue

        if arg.startswith("-") and len(arg) > 1:
            keys.append(arg.split("=", 1)[0])

    return keys


def command_conflicting_flags(user_args, managed_args, pair_flags=None, reserved_flag_keys=None):
    user_argv = _validate_string_list(user_args, "user_args")
    managed_argv = _validate_string_list(managed_args, "managed_args")
    reserved_keys = _validate_string_list(reserved_flag_keys, "reserved_flag_keys")

    user_keys = command_flag_keys(user_argv, pair_flags)
    managed_keys = set(command_flag_keys(managed_argv, pair_flags))
    managed_keys.update(reserved_keys)

    return _unique([key for key in user_keys if key in managed_keys])


class FilterModule:
    def filters(self):
        return {
            "command_flag_keys": command_flag_keys,
            "command_conflicting_flags": command_conflicting_flags,
        }
