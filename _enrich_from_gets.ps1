# Apply eca-get-* / eca-block-config-get JSON caches onto Markdown pages.
# Expected layout under docs/eca-kb/raw/enrich/:
#   events/<safe>.json   - array or object from eca-get-event
#   actions/<safe>.json  - from eca-get-action OR eca-block-config-get
#   valuations/<safe>.json
#   types/<safe>.json
#   _progress.json       - optional status
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$enrichRoot = Join-Path $root 'raw\enrich'

function Get-SafeName([string]$name) {
  if ([string]::IsNullOrEmpty($name)) { return '_unnamed' }
  $s = $name -replace '::', '__'
  return ($s -replace '[\\/:*?"<>|]', '_')
}

function Get-Prop($obj, [string]$n) {
  if ($null -eq $obj) { return $null }
  $p = $obj.PSObject.Properties[$n]
  if ($null -eq $p) { return $null }
  return $p.Value
}

function Resolve-Def($jsonObj, [string]$expectedName) {
  if ($null -eq $jsonObj) { return $null }
  if ($jsonObj -is [System.Array]) {
    if ($jsonObj.Count -eq 0) { return $null }
    if (-not [string]::IsNullOrEmpty($expectedName)) {
      $exact = $jsonObj | Where-Object { [string](Get-Prop $_ 'name') -eq $expectedName } | Select-Object -First 1
      if ($exact) { return $exact }
      # Never apply a wrong fuzzy hit when an expected name was provided.
      return $null
    }
    return $jsonObj[0]
  }
  if (-not [string]::IsNullOrEmpty($expectedName)) {
    $n = [string](Get-Prop $jsonObj 'name')
    if ($n -and $n -ne $expectedName) { return $null }
  }
  return $jsonObj
}

function Format-Params($params, $rawText = $null) {
  if ($null -eq $params) {
    if ($null -ne $rawText -and $rawText -match '"params"\s*:\s*\[\s*\]') {
      $em = [string][char]0x2014
      return "(none $em empty params array from MCP get)`n"
    }
    return "UNKNOWN`n"
  }
  if ($params -is [System.Array] -and $params.Count -eq 0) {
    $em = [string][char]0x2014
    return "(none $em empty params array from MCP get)`n"
  }
  if ($params -isnot [System.Array]) { $params = @($params) }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($p in $params) {
    $pn = Get-Prop $p 'name'; if (-not $pn) { $pn = 'UNKNOWN' }
    $pt = Get-Prop $p 'type'; if (-not $pt) { $pt = 'UNKNOWN' }
    $pl = Get-Prop $p 'label'; if (-not $pl) { $pl = 'UNKNOWN' }
    $req = Get-Prop $p 'required'; if ($null -eq $req) { $req = 'UNKNOWN' } else { $req = "$req" }
    $def = Get-Prop $p 'default'; if ($null -eq $def) { $def = 'UNKNOWN' }
    $range = Get-Prop $p 'range'; if ($null -eq $range) { $range = 'UNKNOWN' }
    $desc = Get-Prop $p 'description'; if (-not $desc) { $desc = Get-Prop $p 'desc' }; if (-not $desc) { $desc = 'UNKNOWN' }
    [void]$lines.Add("- **$pn** (``$pt``): Label=$pl; Required=$req; Default=$def; Range=$range; Description=$desc")
  }
  return (($lines -join "`n") + "`n")
}

function Format-EnumItems($items) {
  if ($null -eq $items) { return "UNKNOWN`n" }
  if ($items -is [System.Array] -and $items.Count -eq 0) { return "(none)`n" }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($it in $items) {
    $n = Get-Prop $it 'name'; if (-not $n) { $n = 'UNKNOWN' }
    $v = Get-Prop $it 'value'; if ($null -eq $v) { $v = 'UNKNOWN' }
    $l = Get-Prop $it 'label'; if (-not $l) { $l = $n }
    $at = Get-Prop $it 'apiTarget'; if (-not $at) { $at = 'UNKNOWN' }
    [void]$lines.Add("- ``$n`` = ``$v`` (label: $l; apiTarget: $at)")
  }
  return (($lines -join "`n") + "`n")
}

function Replace-Section([string]$md, [string]$heading, [string]$body) {
  # Replace from ### Heading through next ### or EOF
  $pattern = '(?ms)^### ' + [regex]::Escape($heading) + '\r?\n.*?(?=^### |\z)'
  $replacement = "### $heading`n$body`n"
  if ($md -match $pattern) {
    return [regex]::Replace($md, $pattern, { param($m) $replacement }, 1)
  }
  # append if missing
  return ($md.TrimEnd() + "`n`n### $heading`n$body`n")
}

function Enrich-EventPage($mdPath, $def, $rawText = $null) {
  $md = Get-Content $mdPath -Raw -Encoding UTF8
  $name = [string](Get-Prop $def 'name')
  $label = Get-Prop $def 'label'; if (-not $label) { $label = $name }
  $script = Get-Prop $def 'scriptName'; if (-not $script) { $script = 'UNKNOWN' }
  $owner = Get-Prop $def 'ownerType'; if (-not $owner) { $owner = 'UNKNOWN' }
  $mod = Get-Prop $def 'moduleLib'; if (-not $mod) { $mod = 'UNKNOWN' }
  $target = Get-Prop $def 'apiTarget'; if (-not $target) { $target = 'UNKNOWN' }
  $level = Get-Prop $def 'apiLevel'; if ($null -eq $level) { $level = 'UNKNOWN' }
  $desc = @"
Label: $label. ScriptName: ``$script``. OwnerType: ``$owner``. ModuleLib: ``$mod``. apiTarget: ``$target``. apiLevel: ``$level``.
Source: MCP ``eca-get-event``.
"@
  $inputs = Format-Params (Get-Prop $def 'params') $rawText
  $md = Replace-Section $md 'Description' $desc
  $md = Replace-Section $md 'Inputs' $inputs
  $outBody = "Event OutVar / ``Pn`` fields on Blockly ``e`` when params exist.`nSource: MCP ``eca-get-event``.`n"
  $md = Replace-Section $md 'Outputs' $outBody
  $ver = "UNKNOWN (MCP ``eca-get-event`` enriched 2026-08-06)`n"
  $md = Replace-Section $md 'Version' $ver
  Set-Content $mdPath $md -Encoding UTF8 -NoNewline
}

function Enrich-ActionOrValPage($mdPath, $def, [string]$kind, [string]$toolName) {
  $md = Get-Content $mdPath -Raw -Encoding UTF8
  $name = [string](Get-Prop $def 'name')
  if (-not $name) { $name = [string](Get-Prop $def 'ref') }
  $label = Get-Prop $def 'label'; if (-not $label) { $label = $name }
  $script = Get-Prop $def 'scriptName'
  if (-not $script) { $script = Get-Prop $def 'ref' }
  if (-not $script) { $script = 'UNKNOWN' }
  $mod = Get-Prop $def 'moduleLib'; if (-not $mod) { $mod = 'UNKNOWN' }
  $target = Get-Prop $def 'apiTarget'; if (-not $target) { $target = 'UNKNOWN' }
  $level = Get-Prop $def 'apiLevel'; if ($null -eq $level) { $level = 'UNKNOWN' }
  $cfgId = Get-Prop $def 'id'
  if ($null -eq $cfgId) { $cfgId = Get-Prop $def 'configId' }
  if ($null -eq $cfgId) {
    if ($md -match 'configId=`(\d+)`') { $cfgId = $Matches[1] }
    elseif ($md -match 'extraState\.X = (\d+)') { $cfgId = $Matches[1] }
  }
  $src = Get-Prop $def '_source'
  if ($src) { $toolName = [string]$src }
  elseif ((Get-Prop $def 'feCustom') -or (Get-Prop $def 'blockJson')) {
    if (-not (Get-Prop $def 'moduleLib')) { $toolName = 'eca-block-config-get' }
  }
  $ret = Get-Prop $def 'returnType'
  if ($null -eq $ret) { $ret = Get-Prop $def 'return' }
  # Valuation MCP get uses string `type` as return type. block-config-get uses numeric `type` (block kind) — ignore that.
  if ($null -eq $ret -and $kind -eq 'valuation') {
    $t = Get-Prop $def 'type'
    if ($null -ne $t -and "$t" -notmatch '^\d+$') { $ret = $t }
  }
  $descParts = @("Label: $label. ScriptName: ``$script``. ModuleLib: ``$mod``. apiTarget: ``$target``. apiLevel: ``$level``.")
  if ($null -ne $cfgId) { $descParts += "configId: ``$cfgId``." }
  $descParts += "Source: MCP ``$toolName``."
  $desc = ($descParts -join ' ') + "`n"
  $params = Get-Prop $def 'params'
  $feCustom = Get-Prop $def 'feCustom'
  $blockJson = Get-Prop $def 'blockJson'
  if ($null -eq $params -and ($toolName -eq 'eca-block-config-get' -or $feCustom -or $blockJson)) {
    $inputs = "(none — feCustom/blockJson; params not in config get)`n"
  } else {
    $inputs = Format-Params $params
  }
  $md = Replace-Section $md 'Description' $desc
  $md = Replace-Section $md 'Inputs' $inputs
  if ($kind -eq 'valuation') {
    $rt = if ($ret) { "``$ret``" } else { 'UNKNOWN' }
    $outBody = "Return type: $rt`nSource: MCP ``$toolName``.`n"
  } else {
    $outVarNote = ''
    if ($null -ne $params) {
      $outish = @($params | Where-Object {
        $pn = [string](Get-Prop $_ 'name'); $pl = [string](Get-Prop $_ 'label')
        $pn -match '(?i)OutVar|^IsSuccess$|^Result' -or $pl -match '(?i)^Out'
      })
      if ($outish.Count -gt 0) {
        $names = ($outish | ForEach-Object { [string](Get-Prop $_ 'name') }) -join ', '
        $outVarNote = " OutVar-related params: $names."
      }
    }
    $outBody = "None (statement) unless OutVar params present.$outVarNote`nSource: MCP ``$toolName``.`n"
  }
  $md = Replace-Section $md 'Outputs' $outBody
  $ver = "enriched (MCP ``$toolName`` 2026-08-06)`n"
  $md = Replace-Section $md 'Version' $ver
  Set-Content $mdPath $md -Encoding UTF8 -NoNewline
}

function Enrich-TypePage($mdPath, $def) {
  $md = Get-Content $mdPath -Raw -Encoding UTF8
  $name = [string](Get-Prop $def 'name')
  $label = Get-Prop $def 'label'; if (-not $label) { $label = $name }
  $script = Get-Prop $def 'scriptName'; if (-not $script) { $script = 'UNKNOWN' }
  $mod = Get-Prop $def 'moduleLib'; if (-not $mod) { $mod = 'UNKNOWN' }
  $level = Get-Prop $def 'apiLevel'; if ($null -eq $level) { $level = 'UNKNOWN' }
  $bases = Get-Prop $def 'bases'; if (-not $bases) { $bases = 'UNKNOWN' }
  if ($bases -is [System.Array]) { $bases = ($bases -join ', ') }
  $isEnum = Get-Prop $def 'isEnum'; if ($null -eq $isEnum) { $isEnum = 'UNKNOWN' }
  $isGeneric = Get-Prop $def 'isGeneric'; if ($null -eq $isGeneric) { $isGeneric = 'UNKNOWN' }
  $tpc = Get-Prop $def 'typeParamCount'; if ($null -eq $tpc) { $tpc = 'UNKNOWN' }
  $desc = @"
Label: $label. ScriptName: ``$script``. ModuleLib: ``$mod``. apiLevel: ``$level``. bases: ``$bases``. isEnum: $isEnum. isGeneric: $isGeneric. typeParamCount: $tpc.
Source: MCP ``eca-get-type``.
"@
  $md = Replace-Section $md 'Description' $desc

  $items = Get-Prop $def 'items'
  $typeParams = Get-Prop $def 'typeParams'
  $props = Get-Prop $def 'properties'
  if ($null -eq $props) { $props = Get-Prop $def 'props' }

  $inputBody = ""
  if ($isEnum -eq $true) {
    $inputBody += (Format-EnumItems $items)
  } elseif (($null -ne $items) -and (@($items).Count -gt 0)) {
    $propLines = New-Object System.Collections.Generic.List[string]
    foreach ($it in @($items)) {
      $n = Get-Prop $it 'name'; if (-not $n) { $n = 'UNKNOWN' }
      $v = Get-Prop $it 'value'; if ($null -eq $v) { $v = 'UNKNOWN' }
      $l = Get-Prop $it 'label'; if (-not $l) { $l = $n }
      $at = Get-Prop $it 'apiTarget'; if (-not $at) { $at = 'UNKNOWN' }
      $ty = Get-Prop $it 'type'; if (-not $ty) { $ty = 'UNKNOWN' }
      [void]$propLines.Add("- **$n** (``$ty``): label: $l; apiTarget: $at; value: ``$v``")
    }
    $inputBody += "Properties:`n" + (($propLines -join "`n") + "`n")
  }
  if (($null -ne $typeParams) -and (@($typeParams).Count -gt 0)) {
    $tpLines = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($typeParams)) {
      $pn = Get-Prop $p 'name'; if (-not $pn) { $pn = 'UNKNOWN' }
      $pt = Get-Prop $p 'type'
      if (-not $pt) { $pt = Get-Prop $p 'constraint' }
      if (-not $pt) { $pt = 'UNKNOWN' }
      $pl = Get-Prop $p 'label'; if (-not $pl) { $pl = 'UNKNOWN' }
      [void]$tpLines.Add("- **$pn** (``$pt``): Label=$pl")
    }
    $inputBody += "TypeParams:`n" + (($tpLines -join "`n") + "`n")
  }
  if (($null -ne $props) -and (@($props).Count -gt 0)) {
    $inputBody += "Properties:`n" + (Format-Params $props)
  }
  if ([string]::IsNullOrWhiteSpace($inputBody)) {
    $inputBody = "N/A (data type; no items in MCP get)`n"
  }
  $md = Replace-Section $md 'Inputs' $inputBody
  $ver = "enriched via eca-get-type`n"
  $md = Replace-Section $md 'Version' $ver
  Set-Content $mdPath $md -Encoding UTF8 -NoNewline
}

function Apply-Folder([string]$kind, [string]$mdDir, [scriptblock]$enrichFn) {
  $jsonDir = Join-Path $enrichRoot $kind
  if (-not (Test-Path $jsonDir)) { Write-Output "skip missing $jsonDir"; return }
  $ok = 0; $fail = 0
  Get-ChildItem $jsonDir -Filter *.json -File | Where-Object { $_.Name -notlike '*_error.json' } | ForEach-Object {
    try {
      $rawText = Get-Content $_.FullName -Raw -Encoding UTF8
      $raw = $rawText | ConvertFrom-Json
      # filename may be safe name; try read expected name from json
      $def0 = Resolve-Def $raw $null
      $expected = [string](Get-Prop $def0 'name')
      if (-not $expected) { $expected = $_.BaseName -replace '__', '::' }
      $def = Resolve-Def $raw $expected
      if ($null -eq $def) { $fail++; return }
      # find md by scanning Block Name or safe filename
      $safe = $_.BaseName
      $mdPath = Join-Path $mdDir ($safe + '.md')
      if (-not (Test-Path $mdPath)) {
        # fallback search
        $hit = Get-ChildItem $mdDir -Filter *.md | Where-Object {
          (Get-Content $_.FullName -Raw) -match [regex]::Escape("``$expected``")
        } | Select-Object -First 1
        if ($hit) { $mdPath = $hit.FullName } else { $fail++; return }
      }
      if ($kind -eq 'events') {
        Enrich-EventPage $mdPath $def $rawText
      } else {
        & $enrichFn $mdPath $def
      }
      $ok++
    } catch {
      Write-Output ("FAIL {0}: {1}" -f $_.Name, $_.Exception.Message)
      $fail++
    }
  }
  Write-Output "$kind applied ok=$ok fail=$fail"
}

Apply-Folder 'events' (Join-Path $root 'events') { param($p,$d) Enrich-EventPage $p $d }
Apply-Folder 'actions' (Join-Path $root 'actions') { param($p,$d) Enrich-ActionOrValPage $p $d 'action' 'eca-get-action' }
Apply-Folder 'valuations' (Join-Path $root 'valuations') { param($p,$d) Enrich-ActionOrValPage $p $d 'valuation' 'eca-get-valuation' }
Apply-Folder 'types' (Join-Path $root 'types') { param($p,$d) Enrich-TypePage $p $d }

Write-Output 'enrich-from-gets done'
