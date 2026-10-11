<#
.SYNOPSIS
  Télécharge les modèles depuis leurs sources officielles (Hugging Face, GitHub) et vérifie leur SHA256.

.PARAMETER Groupes
  sdxl (≈ 13 Go, workflows 1-3), controlnet (≈ 2,5 Go, workflow 4), qwen (≈ 31 Go + 20,5 Go temporaires, workflow 5),
  tout. Défaut : sdxl, controlnet.

.PARAMETER Verifier
  Ne télécharge rien : contrôle la présence et le SHA256 des fichiers.

.EXAMPLE
  .\4-telecharger-modeles.ps1 -Groupes sdxl,controlnet,qwen
#>
param(
    [ValidateSet('sdxl', 'controlnet', 'qwen', 'tout')][string[]]$Groupes = @('sdxl', 'controlnet'),
    [switch]$Verifier
)
. "$PSScriptRoot\commun.ps1"

Etape "Modèles : $($Groupes -join ', ')"
if (-not (Test-ComfyInstalle)) { Echec "ComfyUI introuvable dans $ComfyRacine"; exit 1 }
$opt = @("$PSScriptRoot\telecharger_modeles.py", '--comfyui', $ComfyDossier) + $Groupes + $(if ($Verifier) { @('--verifier') } else { @() })
Invoke-PythonVenv @opt
exit $LASTEXITCODE
