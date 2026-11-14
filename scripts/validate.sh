#!/usr/bin/env bash
# CI for the gateway policy: the generated catalog files are current, the test
# records render (schemas, cross-file rules), the Rego passes opa check, fmt and
# test with them, and both bundles build and load together.
#   needs: python3 with jsonschema and pyyaml, opa
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
ok() { echo "  ok   $*"; }
bad() { echo "  FAIL $*"; fail=1; }

echo "==> catalog (catalog/models.yaml, catalog/tools.yaml)"
if python3 scripts/gen-catalog.py --check; then ok "catalog valid, generated files current"; else bad "catalog (run: python3 scripts/gen-catalog.py)"; fi

echo "==> project data (fixtures/records.yaml, rendered)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
data="$tmp/gateway-projects"
if python3 scripts/render-records.py fixtures/records.yaml --out "$data"; then ok "records render"; else bad "records"; fi

echo "==> opa"
if opa check --strict policies/gateway >/dev/null; then ok "opa check"; else bad "opa check policies/gateway"; fi
if [[ -z "$(opa fmt --list policies/gateway)" ]]; then ok "opa fmt"; else bad "opa fmt (run: opa fmt -w policies/gateway)"; fi
if opa test policies/gateway "$data" >/dev/null; then ok "opa test"; else bad "opa test"; opa test policies/gateway "$data" || true; fi
# Build both bundles as the project registry does (tests left out, roots from each
# .manifest) and load them together, as OPA does: overlapping roots fail here.
if opa build -b policies/gateway --ignore '*_test.rego' -o "$tmp/policy.tar.gz" >/dev/null \
   && opa build -b "$data" -o "$tmp/data.tar.gz" >/dev/null \
   && opa eval -b "$tmp/policy.tar.gz" -b "$tmp/data.tar.gz" --fail 'true' >/dev/null; then
  ok "bundles build and load together"
else
  bad "bundles build and load together"
fi

[[ $fail == 0 ]] && echo "All checks passed." || { echo "Some checks FAILED."; exit 1; }
