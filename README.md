# Craftland Studio PC - ECA Knowledge Base

Live export from Craftland Studio MCP (`craftland-stealapet` / `user-craftland-stealapet`). **No FCG conversion. No invented parameters.**

## Status

| Area | Status | Count |
|------|--------|-------|
| Blockly block types | Documented (schema pages) | 145 |
| Modules | Indexed | 46 |
| Events | Documented + get-enriched | 283 |
| Actions | Documented + get-enriched | 450 |
| Valuations | Documented + get-enriched | 229 |
| Types | Documented + get-enriched | 657 |

Notes:
- Server events (`apiTarget=server`, includes server+both): **250**
- Client events (`apiTarget=client`, includes client+both): **158**
- Merged unique event names (server + client): **283**
- Types: MCP total **657** (case-sensitive; 10 pairs differ only by letter case, e.g. `Object` / `object`)
- Type alias fallbacks (no exact `eca-get-type` name): `array`→List, `entity`→Component, `listGeneric`→ListT

Fields marked **UNKNOWN** were not present in MCP schemas and were not guessed. All events, actions, valuations, and types are get-enriched (`eca-get-*` / config fallback where needed).

## How to use

1. Start from [indexes/block-index.md](indexes/block-index.md) for visual block types (`a`, `v`, `e`, `ife1`, ...).
2. Use [indexes/module-index.md](indexes/module-index.md) then [event](indexes/event-index.md) / action / valuation / [data-type](indexes/data-type-index.md) indexes.
3. Params/enums come from get-enriched pages; re-query MCP `eca-get-*` if Studio version changes.
4. Raw JSON: [raw/](raw/).

## Rules (from MCP)

- Generic API blocks `a` / `v` / `e` require `extraState.X` = valid `configId` from `eca-block-config-list`.
- `apiTarget`: server ECA -> server/both APIs; client ECA -> client/both APIs.
- Avoid deprecated APIs (`apiLevel` 10 / 11). Level 3 is internal.
- Custom events: receive `slr`, send `slsv4`.

## Folders

- `blocks/` - one page per Blockly block type
- `events/` - event docs
- `actions/` - action docs
- `valuations/` - valuation docs
- `types/` - data type docs
- `indexes/` - searchable indexes
- `raw/` - source JSON from MCP

## Variable model (summary)

See MCP `instructions://eca-graph`:

- Graph vars: `grg` / `grs` (by var id)
- Local vars: `lcd` / `lcg` / `lcs`; `vardefId = definingBlockId + fieldName`
- Entity props: `prg` / `prs`; global: `glg` / `gls`
- Replication: UNKNOWN beyond property get/set APIs (`GetReplicationData` / `SetReplicationData`)

## Version

Exported: 2026-08-06 from live Craftland Studio MCP session.
