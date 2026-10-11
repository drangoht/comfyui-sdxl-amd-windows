<#
.SYNOPSIS
  Exécute les workflows du dépôt par l'API de ComfyUI (déjà lancé) et range les images dans sorties-test\.
  Graines fixes : on doit retrouver des images très proches de celles de images\exemples\.

.PARAMETER AvecQwen
  Ajoute le workflow 5 (Qwen-Image-Edit : ≈ 30 Go de modèles, 2 à 6 min).

.PARAMETER Url
  Adresse de ComfyUI (défaut http://127.0.0.1:8188).
#>
param([switch]$AvecQwen, [string]$Url = 'http://127.0.0.1:8188')
. "$PSScriptRoot\commun.ps1"
$UrlComfy = $Url

if (-not (Test-ComfyRepond)) { Echec "ComfyUI ne répond pas sur $Url : le lancer d'abord (lancer-comfyui.ps1)."; exit 1 }
$sorties = Join-Path $DepotRacine 'sorties-test'
$python = if (Test-Path $VenvPython) { $VenvPython } else { 'python' }

$tests = @(
    @{ Nom = '1 - SDXL texte vers image';       Args = @('--seed', '20261011') },
    @{ Nom = '2 - SDXL image vers image';       Args = @('--seed', '5') },
    @{ Nom = "3 - SDXL retouche d'une zone";    Args = @('--seed', '5') },
    @{ Nom = '4 - SDXL guidé par les contours'; Args = @('--seed', '5') }
)
if ($AvecQwen) {
    $tests += @{ Nom = '5 - Qwen édition par instruction'; Args = @('--seed', '5', '--prompt',
        'Replace the cyberpunk city with a sunny Mediterranean fishing harbour in daylight, colorful boats and white houses. Keep the man, his pose, his outfit and the camera angle exactly identical.') }
}

$bilan = @()
foreach ($t in $tests) {
    Etape $t.Nom
    $debut = Get-Date
    $env:PYTHONIOENCODING = 'utf-8'
    & $python -X utf8 "$PSScriptRoot\executer_workflow.py" "$DepotRacine\workflows\$($t.Nom).json" --serveur $Url --sortie $sorties @($t.Args)
    $ok = $LASTEXITCODE -eq 0
    $bilan += [pscustomobject]@{ Workflow = $t.Nom; Resultat = $(if ($ok) { 'OK' } else { 'ÉCHEC' }); Secondes = [int]((Get-Date) - $debut).TotalSeconds }
}

Etape 'Bilan'
$bilan | Format-Table -AutoSize | Out-String | Write-Host
Info "Images : $sorties"
if ($bilan.Resultat -contains 'ÉCHEC') { exit 1 }
