# gateway-policy

The policy of [Mini Platform](https://github.com/nolimitkun/mini-platform-deployment)'s AI gateway. OPA decides every model call, Google API call and MCP tool call that agentgateway receives, with what is in this repo:

| Path | What |
|---|---|
| `policies/gateway/` | the Rego: the decision (`authz.rego`), the model behind `auto` (`select.rego`, `rankings.rego`), what the decision log keeps (`log_mask.rego`), who proposes and who approves a project registry change (`portal.rego`), and their tests. The data classes (`data.json`). This directory is the `gateway-policy` bundle |
| `catalog/models.yaml` | every model and Google API, with its placement (`onprem`, `gcp`, `external`), provider settings and price, and the task classes behind `auto` |
| `catalog/tools.yaml` | every MCP tool behind the gateway, with the most it can do (`read`, `write`, `irreversible`) |
| `projects/schema.json`, `agents/schema.json` | the format of the project registry's records |
| `scripts/gen-projects.py` | validates records against the schemas and the rules across them, and renders the `gateway-projects` bundle |
| `scripts/gen-catalog.py` | validates the catalog and generates `policies/gateway/catalog/data.json` (OPA's `data.catalog`) and `generated/agentgateway-catalog.yaml` (the values of `charts/gateway-models`) |
| `scripts/render-records.py` | renders a file of records (the format of the registry's `/export`) |
| `scripts/policy-replay.py` | replays recent gateway decisions from Loki against the policy in a checkout |
| `scripts/tools-drift.py` | reports MCP tools that appeared, vanished or changed since they were classified |
| `charts/gateway-models` | the gateway's model routes (an AgentgatewayModel per model, the `auto` models, the Google API routes), templated over the catalog: the project registry packages it at the active policy commit and publishes it to its Helm repository in MinIO, which Argo CD installs |
| `fixtures/records.yaml` | the records CI tests the Rego with |

The projects, agents and exceptions themselves are not here: they live in the [project registry](https://github.com/nolimitkun/project-registry), and change there.

## How a change goes live

1. A pull request here, with CI (`scripts/validate.sh`): the catalog's generated files are current, the test records render, the Rego passes `opa check`, `opa fmt` and `opa test`, and both bundles build and load together.
2. Merged to `main`, nothing changes yet. Within a minute the project registry files the commit as a **policy change request**:
   - it tests the commit with its live records rendered at it;
   - it builds and signs the bundle;
   - it replays recent decisions under the active bundles and under the new ones.

   A commit under which neither bundle changes is recorded as `skipped`.
3. The approvers decide in the registry's portal. `portal.rego` (the active one) says who approves: the platform team and security. Then the registry publishes the bundle, and OPA verifies its signature and loads it.

**What the gateway takes from here**, through the project registry, not a pin: once a
policy change is approved, the registry packages `charts/gateway-models` at that commit
with the catalog as its values, and publishes it to its Helm repository in MinIO; the
deployment repo's Argo CD application `gateway-models` installs the newest version. So
a new model is one change here (its placement, and its route), plus its serving
release in the deployment repo for a self-hosted one. A commit that changes the chart
or the catalog is never `skipped`.

The deployment repo's CI checks its own wiring against `main` here: its MCP targets
against `catalog/tools.yaml` `targets`, the semantic router's decisions against the
task classes, and the kagent agents' keys against the seed (`KAGENT_VALUES`,
`KAGENT_RESOURCES`). Its Vault bootstrap runs `scripts/render-records.py` on a new
cluster.

## Locally

```bash
pip install jsonschema pyyaml          # and opa on PATH
./scripts/validate.sh                  # what CI runs
python3 scripts/gen-catalog.py         # after editing catalog/*.yaml
python3 scripts/render-records.py fixtures/records.yaml --out /tmp/gp && opa test policies/gateway /tmp/gp
python3 scripts/policy-replay.py       # needs the cluster: Loki, and the active data from the registry
```

The history of these files before this repo is in the deployment repo (`policies/`, `catalog/`, `scripts/gen-*.py`).
