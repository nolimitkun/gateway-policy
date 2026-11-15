#!/usr/bin/env python3
"""Validate the project registry's setting records and render them for the policy.

The settings are the policy's parameters that reviewers decide, kept as records in the
project registry and changed there with approvals (portal.rego):

    data_classes  the placements each data class allows
    autonomy      the tool risks each agent autonomy may call without a human
    approvals     for each kind of change portal.rego detects, the roles that approve it

The registry (and scripts/render-records.py) writes them as settings/<id>.yaml in a copy
of this repo and runs this script there, before gen-catalog.py and gen-projects.py:

    python3 scripts/gen-settings.py

Each is checked against its id's schema in settings/schema.json. Output: the
gateway-projects bundle's data.registry.settings (policies/gateway-projects/registry/
settings/data.json), keyed by id. Without any setting records nothing is written, and
the policy uses the values it was written with.
"""

import json
import sys
from pathlib import Path

import jsonschema
import yaml

ROOT = Path(__file__).resolve().parent.parent
SETTINGS = ROOT / "settings"
SCHEMA = SETTINGS / "schema.json"
OUT = ROOT / "policies" / "gateway-projects" / "registry" / "settings" / "data.json"


def main() -> int:
    schema = json.loads(SCHEMA.read_text())
    defs = schema.get("$defs", {})
    out, errors = {}, []
    for path in sorted(SETTINGS.glob("*.yaml")):
        sid = path.stem
        if sid not in schema or sid.startswith("$") or sid == "description":
            errors.append(f"settings/{path.name}: no setting {sid!r} (known: {', '.join(k for k in schema if not k.startswith('$') and k != 'description')})")
            continue
        doc = yaml.safe_load(path.read_text())
        validator = jsonschema.Draft202012Validator({**schema[sid], "$defs": defs})
        for e in sorted(validator.iter_errors(doc), key=lambda e: list(e.path)):
            where = ".".join(str(x) for x in e.path) or "(record)"
            errors.append(f"settings/{path.name}: {where}: {e.message}")
        out[sid] = doc
    if errors:
        for e in errors:
            print(e, file=sys.stderr)
        return 1
    if out:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    elif OUT.exists():
        OUT.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
