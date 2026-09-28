# Variables

### Scope
- Graph variables: workspace-level (`eca-graph-list-variables`)
- Local variables: after definition on next-chain / child statements only
- Event params: OutVar fields on event blocks
- Function params: from `fna` / `fnv`

### Lifetime
- Graph vars: for the ECA graph lifetime
- Local vars: from definition through valid scope
- UNKNOWN: exact GC / match reset behavior

### Initialization
- Graph vars: via `eca-graph-add-variable` / editor
- Locals: `lcd` or OutVar from events/actions/loops
- UNKNOWN: default values when not set

### Read/Write
- Graph: `grg` (get), `grs` (set)
- Local: `lcg` (get), `lcs` (set)
- Entity property: `prg` / `prs`
- Global property: `glg` / `gls`

### Replication
- Related APIs: `GetReplicationData`, `SetReplicationData` (StdLibrary)
- Details: UNKNOWN — use `eca-get-action` / `eca-get-valuation` for full params
