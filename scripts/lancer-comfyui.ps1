<#
.SYNOPSIS
  Lance ComfyUI (Launch_ComfyUI.bat) et ouvre http://127.0.0.1:8188 dans le navigateur.

.PARAMETER PrioriteBasse
  Passe ComfyUI en priorité « inférieure à la normale » : le PC reste plus réactif pendant les longues générations.
#>
param([switch]$PrioriteBasse)
. "$PSScriptRoot\commun.ps1"

if (Test-ComfyRepond) { Ok "ComfyUI tourne déjà : $UrlComfy"; Start-Process $UrlComfy; exit 0 }
if (-not (Test-Path $Lanceur)) { Echec "Lanceur introuvable : $Lanceur"; exit 1 }

Info 'Démarrage de ComfyUI (garder sa fenêtre console ouverte : la fermer arrête ComfyUI)…'
Start-Process -FilePath $Lanceur -WorkingDirectory $ComfyRacine
for ($i = 0; $i -lt 120 -and -not (Test-ComfyRepond); $i++) { Start-Sleep 1 }
if (-not (Test-ComfyRepond)) { Echec 'ComfyUI ne répond pas après 2 min : regarder sa fenêtre console.'; exit 1 }
Ok "ComfyUI prêt : $UrlComfy"
if ($PrioriteBasse) {
    Get-ComfyProcessus | ForEach-Object { (Get-Process -Id $_.ProcessId).PriorityClass = 'BelowNormal' }
    Ok 'priorité basse appliquée'
}
