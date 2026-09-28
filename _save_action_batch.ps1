param(
  [Parameter(Mandatory=$true)][string]$BatchFile
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "raw\enrich\actions"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$items = Get-Content $BatchFile -Raw -Encoding UTF8 | ConvertFrom-Json
$saved = 0
foreach ($it in @($items)) {
  $name = [string]$it.name
  if (-not $name) { continue }
  $safe = ($name -replace '::','__') -replace '[\\/:*?"<>|]','_'
  $path = Join-Path $outDir ($safe + ".json")
  $payload = if ($it.PSObject.Properties['payload']) { $it.payload } else { $it }
  if ($payload -is [System.Array]) {
    ($payload | ConvertTo-Json -Depth 40) | Set-Content $path -Encoding UTF8
  } elseif ($payload.feCustom -or $payload.blockJson -or ($null -ne $payload.id -and -not $payload.moduleLib)) {
    if (-not $payload.PSObject.Properties['_source']) {
      $payload | Add-Member -NotePropertyName _source -NotePropertyValue 'eca-block-config-get' -Force
    }
    ($payload | ConvertTo-Json -Depth 40) | Set-Content $path -Encoding UTF8
  } else {
    ,@( $payload ) | ConvertTo-Json -Depth 40 | Set-Content $path -Encoding UTF8
  }
  $saved++
}
Write-Output "saved=$saved dir=$outDir"
