$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$raw = Join-Path $root 'raw'
$typesDir = Join-Path $root 'types'
$eventsDir = Join-Path $root 'events'
$indexesDir = Join-Path $root 'indexes'
New-Item -ItemType Directory -Force -Path $typesDir, $eventsDir, $indexesDir | Out-Null

function Get-SafeName([string]$name) {
  if ([string]::IsNullOrEmpty($name)) { return '_unnamed' }
  $s = $name -replace '::', '__'
  return ($s -replace '[\\/:*?"<>|]', '_')
}

# Windows FS is case-insensitive; disambiguate Object vs object, etc.
function Get-UniqueSafeName([string]$name, [hashtable]$usedLower) {
  $safe = Get-SafeName $name
  $key = $safe.ToLowerInvariant()
  if (-not $usedLower.ContainsKey($key)) {
    $usedLower[$key] = $name
    return $safe
  }
  # collision with different exact name: append case pattern
  $pattern = -join ($name.ToCharArray() | ForEach-Object {
      if ([char]::IsUpper($_)) { 'U' }
      elseif ([char]::IsLower($_)) { 'l' }
      else { 'x' }
    })
  $candidate = '{0}__case_{1}' -f $safe, $pattern
  $ck = $candidate.ToLowerInvariant()
  $n = 2
  while ($usedLower.ContainsKey($ck)) {
    $candidate = '{0}__case_{1}_{2}' -f $safe, $pattern, $n
    $ck = $candidate.ToLowerInvariant()
    $n++
  }
  $usedLower[$ck] = $name
  return $candidate
}

function Get-Prop($obj, [string]$name) {
  if ($null -eq $obj) { return $null }
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p) { return $null }
  return $p.Value
}

function Fmt($val, [switch]$Code) {
  if ($null -eq $val) { return 'UNKNOWN' }
  if ($val -is [bool]) {
    if ($val) { return 'true' } else { return 'false' }
  }
  if ($val -is [System.Array]) {
    if ($val.Count -eq 0) { return '(none)' }
    $parts = @()
    foreach ($x in $val) { $parts += [string]$x }
    if ($Code) {
      return '`' + ($parts -join '`, `') + '`'
    }
    return ($parts -join ', ')
  }
  $str = [string]$val
  if ([string]::IsNullOrWhiteSpace($str)) { return 'UNKNOWN' }
  if ($Code) { return '`' + $str + '`' }
  return $str
}

# ========== TYPES ==========
# Case-sensitive: Object vs object are distinct MCP types
$typeMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
$typeOrder = New-Object System.Collections.Generic.List[string]
foreach ($p in 1..4) {
  $d = Get-Content (Join-Path $raw ("types-p{0}.json" -f $p)) -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($item in $d.items) {
    $n = [string]$item.name
    if (-not $typeMap.ContainsKey($n)) {
      $typeMap[$n] = $item
      [void]$typeOrder.Add($n)
    }
  }
}
Write-Host ("Unique types (case-sensitive): {0}" -f $typeMap.Count)

$typeIndexRows = New-Object System.Collections.Generic.List[string]
$typeWritten = 0
$typeUsedLower = @{}
foreach ($name in $typeOrder) {
  $t = $typeMap[$name]
  $labelVal = Get-Prop $t 'label'
  if ([string]::IsNullOrWhiteSpace([string]$labelVal)) { $labelVal = $name }
  $scriptName = Fmt (Get-Prop $t 'scriptName') -Code
  $moduleLib = Fmt (Get-Prop $t 'moduleLib') -Code
  $apiLevel = Fmt (Get-Prop $t 'apiLevel')
  $bases = Fmt (Get-Prop $t 'bases') -Code
  $isEnum = Fmt (Get-Prop $t 'isEnum')
  $isGeneric = Fmt (Get-Prop $t 'isGeneric')
  $typeParamCount = Fmt (Get-Prop $t 'typeParamCount')
  $conflicts = Fmt (Get-Prop $t 'conflicts') -Code
  $isDynamicAddable = Fmt (Get-Prop $t 'isDynamicAddable')
  $addable = Fmt (Get-Prop $t 'addable') -Code

  $depsParts = New-Object System.Collections.Generic.List[string]
  $b = Get-Prop $t 'bases'
  if ($null -ne $b -and [string]$b -ne '') { [void]$depsParts.Add(('bases: {0}' -f (Fmt $b -Code))) }
  $c = Get-Prop $t 'conflicts'
  if ($null -ne $c) { [void]$depsParts.Add(('conflicts: {0}' -f (Fmt $c -Code))) }
  $a = Get-Prop $t 'addable'
  if ($null -ne $a) { [void]$depsParts.Add(('addable: {0}' -f (Fmt $a -Code))) }
  if ($depsParts.Count -gt 0) { $deps = ($depsParts -join '; ') } else { $deps = 'UNKNOWN' }

  $safe = Get-UniqueSafeName $name $typeUsedLower
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine(('# {0}' -f $labelVal))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Block Name')
  [void]$sb.AppendLine(('`{0}`' -f $name))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Category')
  [void]$sb.AppendLine('Type')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Description')
  [void]$sb.AppendLine(('Label: {0}. ScriptName: {1}. ModuleLib: {2}. apiLevel: {3}. bases: {4}. isEnum: {5} isGeneric: {6} typeParamCount: {7} conflicts: {8} isDynamicAddable: {9} addable: {10}' -f $labelVal, $scriptName, $moduleLib, $apiLevel, $bases, $isEnum, $isGeneric, $typeParamCount, $conflicts, $isDynamicAddable, $addable))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Inputs')
  [void]$sb.AppendLine('N/A (data type)')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Outputs')
  [void]$sb.AppendLine('N/A (data type)')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Execution Type')
  [void]$sb.AppendLine('Data Type')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Dependencies')
  [void]$sb.AppendLine($deps)
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Example Usage')
  [void]$sb.AppendLine('```text')
  [void]$sb.AppendLine('Use as param/return type in ECA actions/valuations/events')
  [void]$sb.AppendLine('```')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Best Practices')
  [void]$sb.AppendLine('- Prefer apiLevel 4; avoid 10/11 when alternatives exist.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Common Mistakes')
  [void]$sb.AppendLine('- Confusing `name` with `scriptName` / label.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Performance Notes')
  [void]$sb.AppendLine('UNKNOWN')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Related Blocks')
  [void]$sb.AppendLine('UNKNOWN')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Version')
  [void]$sb.AppendLine('UNKNOWN (MCP eca-list-types 2026-08-06)')
  Set-Content -LiteralPath (Join-Path $typesDir ($safe + '.md')) -Value $sb.ToString() -Encoding UTF8
  $typeWritten++
  [void]$typeIndexRows.Add(('| `{0}` | {1} | {2} | {3} | {4} | [{5}.md](../types/{5}.md) |' -f $name, $labelVal, $scriptName, $moduleLib, $apiLevel, $safe))
}
Write-Host ("Type pages written: {0}" -f $typeWritten)

$ti = New-Object System.Text.StringBuilder
[void]$ti.AppendLine('# Data Type Index')
[void]$ti.AppendLine('')
[void]$ti.AppendLine(('Source: MCP `eca-list-types` (pages 1-4, pageSize 200). Unique by `name` (case-sensitive): **{0}**. Server total field: 657.' -f $typeMap.Count))
[void]$ti.AppendLine('')
[void]$ti.AppendLine('| Name | Label | ScriptName | ModuleLib | apiLevel | Doc |')
[void]$ti.AppendLine('|------|-------|------------|-----------|----------|-----|')
foreach ($row in $typeIndexRows) { [void]$ti.AppendLine($row) }
[void]$ti.AppendLine('')
[void]$ti.AppendLine('## Version')
[void]$ti.AppendLine('UNKNOWN (MCP eca-list-types 2026-08-06)')
Set-Content -LiteralPath (Join-Path $indexesDir 'data-type-index.md') -Value $ti.ToString() -Encoding UTF8
Write-Host 'Wrote data-type-index.md'

# ========== EVENT CONFIG LOOKUP ==========
$configByKey = @{}
function Add-Config($cfg) {
  if ($null -eq $cfg) { return }
  foreach ($k in @('name', 'ref', 'label')) {
    $v = Get-Prop $cfg $k
    if ($null -ne $v -and [string]$v -ne '') {
      $key = [string]$v
      if (-not $configByKey.ContainsKey($key)) { $configByKey[$key] = $cfg }
    }
  }
}
foreach ($f in @('block-config-events-server-p1.json', 'block-config-events-client-p1.json')) {
  $path = Join-Path $raw $f
  if (-not (Test-Path -LiteralPath $path)) { continue }
  $d = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($null -eq $d.items) { continue }
  foreach ($item in $d.items) { Add-Config $item }
}
Write-Host ("Config lookup keys: {0}" -f $configByKey.Count)

function Find-ConfigId($ev) {
  $candidates = New-Object System.Collections.Generic.List[string]
  $n = [string](Get-Prop $ev 'name')
  $sn = [string](Get-Prop $ev 'scriptName')
  $lb = [string](Get-Prop $ev 'label')
  if ($n) {
    [void]$candidates.Add($n)
    if ($n -match '::(.+)$') { [void]$candidates.Add($Matches[1]) }
  }
  if ($sn) { [void]$candidates.Add($sn) }
  if ($lb) { [void]$candidates.Add($lb) }
  foreach ($c in $candidates) {
    if ($configByKey.ContainsKey($c)) {
      $cfg = $configByKey[$c]
      return @{
        id      = (Get-Prop $cfg 'id')
        matched = $c
        cfgName = (Get-Prop $cfg 'name')
      }
    }
  }
  return $null
}

# ========== EVENTS ==========
$eventMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
$eventOrder = New-Object System.Collections.Generic.List[string]
foreach ($f in @('events-server-p1.json', 'events-server-p2.json', 'events-client-p1.json')) {
  $d = Get-Content (Join-Path $raw $f) -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($item in $d.items) {
    $n = [string]$item.name
    if (-not $eventMap.ContainsKey($n)) {
      $eventMap[$n] = $item
      [void]$eventOrder.Add($n)
    }
    else {
      $old = $eventMap[$n]
      $oldT = [string](Get-Prop $old 'apiTarget')
      $newT = [string](Get-Prop $item 'apiTarget')
      if ($oldT -eq 'client' -and ($newT -eq 'server' -or $newT -eq 'both')) {
        $eventMap[$n] = $item
      }
    }
  }
}
Write-Host ("Unique events (case-sensitive): {0}" -f $eventMap.Count)

$eventIndexRows = New-Object System.Collections.Generic.List[string]
$eventWritten = 0
$configMatched = 0
$eventUsedLower = @{}
foreach ($name in $eventOrder) {
  $ev = $eventMap[$name]
  $labelVal = Get-Prop $ev 'label'
  if ([string]::IsNullOrWhiteSpace([string]$labelVal)) { $labelVal = $name }
  $scriptName = Fmt (Get-Prop $ev 'scriptName') -Code
  $ownerType = Fmt (Get-Prop $ev 'ownerType') -Code
  $moduleLib = Fmt (Get-Prop $ev 'moduleLib') -Code
  $apiTarget = Fmt (Get-Prop $ev 'apiTarget') -Code
  $apiLevel = Fmt (Get-Prop $ev 'apiLevel') -Code
  $cfgHit = Find-ConfigId $ev
  $configIdText = 'UNKNOWN'
  $depsExtra = 'Top-level Blockly `e`; resolve configId via `eca-block-config-list` type=1 search.'
  if ($null -ne $cfgHit) {
    $configIdText = ('`{0}` (matched `{1}`)' -f $cfgHit.id, $cfgHit.matched)
    $depsExtra = ('Top-level Blockly `e`; `extraState.X` = {0}.' -f $cfgHit.id)
    $configMatched++
  }

  $safe = Get-UniqueSafeName $name $eventUsedLower
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine(('# {0}' -f $labelVal))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Block Name')
  [void]$sb.AppendLine(('`{0}`' -f $name))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Category')
  [void]$sb.AppendLine('Event')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Description')
  [void]$sb.AppendLine(('Label: {0}. ScriptName: {1}. OwnerType: {2}. ModuleLib: {3}. apiTarget: {4}. apiLevel: {5}. configId: {6}.' -f $labelVal, $scriptName, $ownerType, $moduleLib, $apiTarget, $apiLevel, $configIdText))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Inputs')
  [void]$sb.AppendLine(('UNKNOWN - list tools omit params. Confirm with MCP `eca-get-event` query `{0}` (or short name).' -f $name))
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Outputs')
  [void]$sb.AppendLine('Event event-out / `Pn` fields on Blockly `e` when params exist. Param schemas: UNKNOWN from list tools.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Execution Type')
  [void]$sb.AppendLine('Event')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Dependencies')
  [void]$sb.AppendLine($depsExtra)
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Example Usage')
  [void]$sb.AppendLine('```text')
  [void]$sb.AppendLine(('Event block e (config for {0}) -> action chain' -f $name))
  [void]$sb.AppendLine('```')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Best Practices')
  [void]$sb.AppendLine('- Prefer apiLevel 4; avoid 10/11 when alternatives exist.')
  [void]$sb.AppendLine('- Match ECA platform to apiTarget.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Common Mistakes')
  [void]$sb.AppendLine('- Using server-only event on client ECA.')
  [void]$sb.AppendLine('- Missing `extraState.X`.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Performance Notes')
  [void]$sb.AppendLine('UNKNOWN (OnUpdate / FixedUpdate may be hot - UNKNOWN cost).')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Related Blocks')
  [void]$sb.AppendLine('UNKNOWN')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('### Version')
  [void]$sb.AppendLine('UNKNOWN (MCP `eca-list-events` 2026-08-06)')
  Set-Content -LiteralPath (Join-Path $eventsDir ($safe + '.md')) -Value $sb.ToString() -Encoding UTF8
  $eventWritten++
  [void]$eventIndexRows.Add(('| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} | {7} | [{8}.md](../events/{8}.md) |' -f $name, $labelVal, $scriptName, $ownerType, $apiTarget, $apiLevel, $moduleLib, $configIdText, $safe))
}
Write-Host ("Event pages written: {0} configMatched: {1}" -f $eventWritten, $configMatched)

$ei = New-Object System.Text.StringBuilder
[void]$ei.AppendLine('# Event Index')
[void]$ei.AppendLine('')
[void]$ei.AppendLine('Source: MCP `eca-list-events`')
[void]$ei.AppendLine('- `apiTarget=server` (server+both): total **250** (pages 1-2)')
[void]$ei.AppendLine('- `apiTarget=client` (client+both): total **158** (page 1, hasMore=false)')
[void]$ei.AppendLine(('- Merged unique by `name` (case-sensitive): **{0}**' -f $eventMap.Count))
[void]$ei.AppendLine('')
[void]$ei.AppendLine('configId from `eca-block-config-list` type=1 when name/ref/label matched; else UNKNOWN.')
[void]$ei.AppendLine('')
[void]$ei.AppendLine('| Name | Label | ScriptName | OwnerType | apiTarget | apiLevel | Module | configId | Doc |')
[void]$ei.AppendLine('|------|-------|------------|-----------|-----------|----------|--------|----------|-----|')
foreach ($row in $eventIndexRows) { [void]$ei.AppendLine($row) }
[void]$ei.AppendLine('')
[void]$ei.AppendLine('## Version')
[void]$ei.AppendLine('UNKNOWN (MCP eca-list-events / eca-block-config-list 2026-08-06)')
Set-Content -LiteralPath (Join-Path $indexesDir 'event-index.md') -Value $ei.ToString() -Encoding UTF8
Write-Host 'Wrote event-index.md'

# ========== README ==========
$blocks = @(Get-ChildItem (Join-Path $root 'blocks') -Filter *.md -ErrorAction SilentlyContinue).Count
$actions = @(Get-ChildItem (Join-Path $root 'actions') -Filter *.md -ErrorAction SilentlyContinue).Count
$valuations = @(Get-ChildItem (Join-Path $root 'valuations') -Filter *.md -ErrorAction SilentlyContinue).Count
$events = @(Get-ChildItem $eventsDir -Filter *.md).Count
$types = @(Get-ChildItem $typesDir -Filter *.md).Count

$rb = New-Object System.Text.StringBuilder
[void]$rb.AppendLine('# Craftland Studio PC — ECA Knowledge Base')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('Live export from Craftland Studio MCP (`craftland-stealapet` / `user-craftland-stealapet`). **No FCG conversion. No invented parameters.**')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## Status')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('| Area | Status | Count |')
[void]$rb.AppendLine('|------|--------|-------|')
[void]$rb.AppendLine(('| Blockly block types | Documented (schema pages) | {0} |' -f $blocks))
[void]$rb.AppendLine('| Modules | Indexed | 46 |')
[void]$rb.AppendLine(('| Events | Documented (unique by name) | {0} |' -f $events))
[void]$rb.AppendLine(('| Actions | Documented (catalog pages) | {0} |' -f $actions))
[void]$rb.AppendLine(('| Valuations | Documented (catalog pages) | {0} |' -f $valuations))
[void]$rb.AppendLine(('| Types | Documented (unique by name) | {0} |' -f $types))
[void]$rb.AppendLine('')
[void]$rb.AppendLine('Fields marked **UNKNOWN** were not present in MCP list schemas and were not guessed. Use `eca-get-event` / `eca-get-action` / `eca-get-valuation` / `eca-get-type` for full params/items.')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## How to use')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('1. Start from [indexes/block-index.md](indexes/block-index.md) for visual block types (`a`, `v`, `e`, `ife1`, …).')
[void]$rb.AppendLine('2. Use [indexes/module-index.md](indexes/module-index.md) then [event](indexes/event-index.md) / action / valuation / [data-type](indexes/data-type-index.md) indexes.')
[void]$rb.AppendLine('3. For full params of an API, use MCP `eca-get-event` / `eca-get-action` / `eca-get-valuation` / `eca-get-type` (list tools are summaries only).')
[void]$rb.AppendLine('4. Raw JSON: [raw/](raw/).')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## Rules (from MCP)')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('- Generic API blocks `a` / `v` / `e` require `extraState.X` = valid `configId` from `eca-block-config-list`.')
[void]$rb.AppendLine('- `apiTarget`: server ECA -> server/both APIs; client ECA -> client/both APIs.')
[void]$rb.AppendLine('- Avoid deprecated APIs (`apiLevel` 10 / 11). Level 3 is internal.')
[void]$rb.AppendLine('- Custom events: receive `slr`, send `slsv4`.')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## Folders')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('- `blocks/` — one page per Blockly block type')
[void]$rb.AppendLine('- `events/` — event docs')
[void]$rb.AppendLine('- `actions/` — action docs')
[void]$rb.AppendLine('- `valuations/` — valuation docs')
[void]$rb.AppendLine('- `types/` — data type docs')
[void]$rb.AppendLine('- `indexes/` — searchable indexes')
[void]$rb.AppendLine('- `raw/` — source JSON from MCP')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## Variable model (summary)')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('See MCP `instructions://eca-graph`:')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('- Graph vars: `grg` / `grs` (by var id)')
[void]$rb.AppendLine('- Local vars: `lcd` / `lcg` / `lcs`; `vardefId = definingBlockId + fieldName`')
[void]$rb.AppendLine('- Entity props: `prg` / `prs`; global: `glg` / `gls`')
[void]$rb.AppendLine('- Replication: UNKNOWN beyond property get/set APIs (`GetReplicationData` / `SetReplicationData`)')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('## Version')
[void]$rb.AppendLine('')
[void]$rb.AppendLine('Exported: 2026-08-06 from live Craftland Studio MCP session.')
Set-Content -LiteralPath (Join-Path $root 'README.md') -Value $rb.ToString() -Encoding UTF8

Write-Host '=== FINAL COUNTS ==='
Write-Host ("blocks={0} actions={1} valuations={2} events={3} types={4}" -f $blocks, $actions, $valuations, $events, $types)
Write-Host ("indexes: {0}" -f ((Get-ChildItem $indexesDir -Filter '*.md' | Select-Object -ExpandProperty Name) -join ', '))
