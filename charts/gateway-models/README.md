# gateway-models

The gateway's model routes, templated over the catalog (`catalog/models.yaml`):

- one `AgentgatewayModel` per model: a KServe release routes to its InferencePool in
  its serving namespace, with the name vLLM serves; Vertex AI and DeepSeek models
  route to their provider;
- `auto` and `auto-<task>`: virtual models that ask OPA which model the caller's
  project gets (`policies/gateway/select.rego`);
- each Google API: an `AgentgatewayBackend` and an `HTTPRoute` under `/google/<name>/`.

Nobody installs this directory as it is. Once a policy commit is approved and active,
the project registry packages the chart at that commit with
`generated/agentgateway-catalog.yaml` as its `catalog` value, as version `1.0.<n>`,
and publishes it to its Helm repository in MinIO (bucket `gateway-models`). The
deployment repo's Argo CD application `gateway-models` installs the newest version
with the gateway's own values (`gatewayName`, `gcp`, `kserve`, `auto`).

A change here or to the catalog is therefore a policy change: tested, replayed,
approved, then live within a few minutes (Argo CD polls the repository).
