<#
.SYNOPSIS
  Installation complète, à lancer une fois l'AMD AI Bundle (composant ComfyUI) installé :
  vérification -> PyTorch ROCm 10 -> choix du GPU -> modèles -> workflows.

.PARAMETER Gfx
  Architecture du GPU : gfx1201 (RX 9070 / 9070 XT, défaut), gfx1200 (RX 9060 XT), gfx1151 (Ryzen AI Max).

.PARAMETER Modeles
  Groupes de modèles à télécharger : sdxl, controlnet, qwen, tout. Défaut : sdxl, controlnet (≈ 16 Go).

.PARAMETER SansTelechargement
  Ne télécharge pas les modèles, vérifie seulement leur présence (utile si on les a déjà).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\installer.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\installer.ps1 -Modeles tout
#>
param(
    [ValidateSet('gfx1201', 'gfx1200', 'gfx1151')][string]$Gfx = 'gfx1201',
    [ValidateSet('sdxl', 'controlnet', 'qwen', 'tout')][string[]]$Modeles = @('sdxl', 'controlnet'),
    [switch]$SansTelechargement
)
. "$PSScriptRoot\commun.ps1"
$debut = Get-Date

function Lancer([string]$script, [hashtable]$params = @{}) {
    & "$PSScriptRoot\$script" @params
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Echec "$script a échoué (code $LASTEXITCODE) : installation interrompue."; exit $LASTEXITCODE }
}

if (-not (Test-ComfyInstalle)) {
    Echec "ComfyUI introuvable dans $ComfyRacine"
    Info  "Étape 1 manuelle : installer l'AMD AI Bundle avec le composant ComfyUI (docs\02-installation.md)."
    exit 1
}
if (Get-ComfyProcessus) { Echec 'ComfyUI est en cours d''exécution : fermer sa fenêtre console, puis relancer.'; exit 1 }

Lancer '2-installer-pytorch-rocm10.ps1' @{ Gfx = $Gfx }
Lancer '3-configurer-lanceur.ps1' @{ Gfx = $Gfx }
Lancer '4-telecharger-modeles.ps1' @{ Groupes = $Modeles; Verifier = [bool]$SansTelechargement }
Lancer '5-installer-workflows.ps1'

Etape 'Terminé'
Ok ("Installation faite en {0:N0} min." -f ((Get-Date) - $debut).TotalMinutes)
Info 'Lancer ComfyUI   : scripts\lancer-comfyui.ps1   (ou Launch_ComfyUI.bat)'
Info 'Tester les workflows : scripts\tester-installation.ps1   (ComfyUI lancé)'
