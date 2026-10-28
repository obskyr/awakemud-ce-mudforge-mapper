#!/usr/bin/env python

"""Align the metadata in `plugins.json` with what’s found in the individual
plugins, including setting the checksum. Add it as a pre-commit hook!
"""


import hashlib
import json
import re
import subprocess
import sys


# Of course, this doesn’t work with arbitrary Lua tables, but thankfully,
# we don’t need to support arbitrary Lua tables.
PLUGIN_TABLE_RE = re.compile(
    r'\Aplugin\s*=\s*(?P<table>\{.*^}$)',
    re.MULTILINE | re.DOTALL
)
LUA_KEY_VALUE_RE = re.compile(
    r'^\s*(?P<key>\w+)\s*=\s*(?P<value>".*"|\'.*\'),?$',
    re.MULTILINE
)


def main():
    with open('plugins.json', 'r', encoding='utf-8') as f:
        plugins_d = json.load(f)

    for plugin in plugins_d['plugins']:
        with open(plugin['downloadUrl'], 'r', encoding='utf-8') as f:
            s = f.read()
            m = PLUGIN_TABLE_RE.match(s)

        table_s = m.group('table')
        plugin_metadata = {
            m.group('key'): m.group('value')[1:-1]
            for m in LUA_KEY_VALUE_RE.finditer(table_s)
        }
        plugin.update(plugin_metadata)

        with open(plugin['downloadUrl'], 'rb', buffering=0) as f:
            plugin['sha256'] = hashlib.file_digest(f, 'sha256').hexdigest()

    with open('plugins.json', 'w', encoding='utf-8') as f:
        json.dump(plugins_d, f, indent=4, ensure_ascii=False)
        f.write("\n")

    subprocess.run(('git', 'add', 'plugins.json'))

    return 0


if __name__ == '__main__':
    sys.exit(main())
