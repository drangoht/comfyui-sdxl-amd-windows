# Chemins et fonctions partagés par les scripts (chargé par « . $PSScriptRoot\commun.ps1 »).
# Adapter ici si ComfyUI n'est pas installé par l'AMD AI Bundle.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # sinon Invoke-WebRequest / Expand-Archive sont très lents sous PowerShell 5.1
[Console]::OutputEncoding = [Text.Encoding]::UTF8   # accents des scripts Python

# Installation de l'AMD AI Bundle ; la variable d'environnement COMFYUI_RACINE permet d'en viser une autre
# (tests\tester-tout.ps1 s'en sert pour travailler sur une copie).
$ComfyRacine  = if ($env:COMFYUI_RACINE) { $env:COMFYUI_RACINE } else { Join-Path $env:LOCALAPPDATA 'AMD\AI_Bundle\ComfyUI' }
$ComfyDossier = Join-Path $ComfyRacine 'ComfyUI'                      # le dépôt ComfyUI (main.py, models\, input\, output\)
$VenvPython   = Join-Path $ComfyRacine 'venv\Scripts\python.exe'
$Lanceur      = Join-Path $ComfyRacine 'Launch_ComfyUI.bat'
$DepotRacine  = Split-Path $PSScriptRoot
$UrlComfy     = 'http://127.0.0.1:8188'

function Etape([string]$t)     { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok([string]$t)        { Write-Host "  [OK] $t" -ForegroundColor Green }
function Attention([string]$t) { Write-Host "  [!]  $t" -ForegroundColor Yellow }
function Echec([string]$t)     { Write-Host "  [X]  $t" -ForegroundColor Red }
function Info([string]$t)      { Write-Host "       $t" }

function Test-ComfyInstalle {
    (Test-Path (Join-Path $ComfyDossier 'main.py')) -and (Test-Path $VenvPython)
}

# Processus python de ComfyUI en cours (lancé depuis ce dossier d'installation)
function Get-ComfyProcessus {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object { $_.CommandLine -like '*main.py*' -and $_.ExecutablePath -like "$ComfyRacine*" }
}

function Test-ComfyRepond {
    try { Invoke-WebRequest "$UrlComfy/system_stats" -UseBasicParsing -TimeoutSec 3 | Out-Null; $true } catch { $false }
}

# Lance un script Python du dépôt avec le Python du venv de ComfyUI (sortie en UTF-8 pour les accents)
function Invoke-PythonVenv {
    $env:PYTHONIOENCODING = 'utf-8'
    & $VenvPython -X utf8 @args
}
