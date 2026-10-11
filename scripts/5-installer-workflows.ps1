<#
.SYNOPSIS
  Copie les workflows du dépôt dans ComfyUI (onglet « Workflows ») et les images de départ dans son dossier input.

.PARAMETER Force
  Remplace un workflow existant qui a été modifié (sinon il est conservé et signalé).
#>
param([switch]$Force)
. "$PSScriptRoot\commun.ps1"

Etape 'Workflows et images de départ'
if (-not (Test-ComfyInstalle)) { Echec "ComfyUI introuvable dans $ComfyRacine"; exit 1 }

$paires = @(
    @{ Source = "$DepotRacine\workflows"; Dest = Join-Path $ComfyDossier 'user\default\workflows'; Filtre = '*.json' },
    @{ Source = "$DepotRacine\entrees";   Dest = Join-Path $ComfyDossier 'input';                  Filtre = '*.png' }
)
foreach ($p in $paires) {
    New-Item -ItemType Directory -Force $p.Dest | Out-Null
    foreach ($f in Get-ChildItem $p.Source -Filter $p.Filtre) {
        $cible = Join-Path $p.Dest $f.Name
        if (-not (Test-Path $cible)) { Copy-Item $f.FullName $cible; Ok "$($f.Name) installé" }
        elseif ((Get-FileHash $cible).Hash -eq (Get-FileHash $f.FullName).Hash) { Ok "$($f.Name) déjà à jour" }
        elseif ($Force) { Copy-Item $f.FullName $cible -Force; Ok "$($f.Name) remplacé" }
        else { Attention "$($f.Name) existe et a été modifié : conservé (-Force pour le remplacer)" }
    }
}
Info 'Dans ComfyUI : barre latérale gauche -> onglet Workflows.'
