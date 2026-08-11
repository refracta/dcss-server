#!/usr/bin/env python3

"""Install or update the CNC DWEM module block in a Webtiles template."""

import argparse
import json
import re
import sys
from pathlib import Path


DWEM_MODULES = (
    "io-hook",
    "site-information",
    "websocket-factory",
    "rc-manager",
    "command-manager",
    "module-manager",
    "cnc-banner",
    "cnc-userinfo",
    "sound-support",
    "cnc-chat",
    "cnc-public-chat",
    "cnc-event",
    "convenience-module",
    "cnc-splash-screen",
    "wtrec",
    "advanced-rc-editor",
    "translation-module",
    "map-predictor",
)

SCRIPT_TAG = '<script type="text/javascript">'
WEBTILES_CONFIG_SCRIPT_RE = re.compile(
    r'(?P<tag><script[ \t]+type="text/javascript">)'
    r'(?P<body>.*?)'
    r'</script>',
    re.DOTALL,
)
INJECTED_BLOCK_RE = re.compile(
    r'<script[ \t]+type="text/javascript">(?P<newline>\r?\n)'
    r'(?:[ \t]*localStorage\.removeItem\("DWEM"\);[ \t]*(?P=newline))?'
    r'[ \t]*localStorage\.DWEM_MODULES[ \t]*=[ \t]*JSON\.stringify\([ \t]*'
    r'(?P=newline)'
    r'[ \t]*\[[^\r\n]*\]\.map\(m[ \t]*=>[ \t]*'
    r'"\.\./modules/"[ \t]*\+[ \t]*m[ \t]*\+[ \t]*"/index\.js"\)'
    r'[ \t]*(?P=newline)'
    r'[ \t]*\);'
)


class TemplateUpdateError(RuntimeError):
    """Raised when the template is not in a known, safely editable state."""


def render_block(newline):
    modules = json.dumps(DWEM_MODULES)
    return newline.join(
        (
            SCRIPT_TAG,
            '      localStorage.removeItem("DWEM");',
            "      localStorage.DWEM_MODULES = JSON.stringify(",
            f'        {modules}.map(m => "../modules/" + m + "/index.js")',
            "      );",
        )
    )


def detect_newline(contents):
    newline_at = contents.find("\n")
    if newline_at > 0 and contents[newline_at - 1] == "\r":
        return "\r\n"
    return "\n"


def updated_contents(contents):
    config_scripts = [
        match
        for match in WEBTILES_CONFIG_SCRIPT_RE.finditer(contents)
        if "socket_server" in match.group("body")
        and "game_version" in match.group("body")
    ]
    if len(config_scripts) != 1:
        raise TemplateUpdateError(
            "expected one Webtiles configuration script containing "
            f"socket_server and game_version, found {len(config_scripts)}"
        )
    config_script = config_scripts[0]

    injected_blocks = list(INJECTED_BLOCK_RE.finditer(contents))
    if len(injected_blocks) > 1:
        raise TemplateUpdateError(
            f"expected one DWEM module block, found {len(injected_blocks)}"
        )
    if injected_blocks:
        match = injected_blocks[0]
        outside_block = contents[: match.start()] + contents[match.end() :]
        if (
            match.start() != config_script.start()
            or "localStorage.DWEM_MODULES" in outside_block
            or 'localStorage.removeItem("DWEM")' in outside_block
        ):
            raise TemplateUpdateError(
                "found DWEM configuration outside the known block"
            )
        return (
            contents[: match.start()]
            + render_block(match.group("newline"))
            + contents[match.end() :]
        )

    if (
        "localStorage.DWEM_MODULES" in contents
        or 'localStorage.removeItem("DWEM")' in contents
    ):
        raise TemplateUpdateError("found an unrecognized DWEM configuration block")

    if config_script.group("tag") != SCRIPT_TAG:
        raise TemplateUpdateError("the Webtiles configuration script is not pristine")

    start = config_script.start()
    end = start + len(SCRIPT_TAG)
    return contents[:start] + render_block(detect_newline(contents)) + contents[end:]


def update_template(path):
    original = path.read_bytes()
    contents = original.decode("utf-8")
    updated = updated_contents(contents).encode("utf-8")
    if updated != original:
        path.write_bytes(updated)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("template", type=Path)
    args = parser.parse_args(argv)

    try:
        update_template(args.template)
    except (OSError, UnicodeError, TemplateUpdateError) as error:
        print(f"{parser.prog}: {args.template}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
