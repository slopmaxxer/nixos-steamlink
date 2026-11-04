"""Replays the symlink() and set_perm*() calls of a Steam Link update's updater-script
(Android edify) on the extracted system/ tree: the zip stores neither links nor modes.

usage: apply-updater-script.py <updater-script> <system dir>
"""

import os
import re
import sys

script_path, root = sys.argv[1:]
script = open(script_path).read()


def target(path):
    assert path.startswith("/system/"), path
    return os.path.join(root, path[len("/system/"):])


def args(call):
    return re.findall(r'"([^"]*)"|(\d+)', call)


for name, body in re.findall(r"\b(symlink|set_perm_recursive|set_perm)\(([^)]*)\);", script):
    values = [s or n for s, n in args(body)]
    if name == "symlink":
        link_target, links = values[0], values[1:]
        for link in links:
            path = target(link)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            if os.path.lexists(path):
                os.remove(path)
            os.symlink(link_target, path)
    elif name == "set_perm":
        os.chmod(target(values[3]), int(values[2], 8))
    else:  # set_perm_recursive(uid, gid, dirmode, filemode, path)
        dir_mode, file_mode, top = int(values[2], 8), int(values[3], 8), target(values[4])
        for dirpath, dirnames, filenames in os.walk(top):
            os.chmod(dirpath, dir_mode)
            for f in filenames:
                p = os.path.join(dirpath, f)
                if not os.path.islink(p):
                    os.chmod(p, file_mode)
