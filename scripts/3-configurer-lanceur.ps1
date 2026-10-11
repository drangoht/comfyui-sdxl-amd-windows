<#
.SYNOPSIS
  Fait lancer ComfyUI sur la bonne carte graphique en ajoutant « --cuda-device N » à Launch_ComfyUI.bat.

.DESCRIPTION
  Sur un PC avec processeur Ryzen à graphiques intégrés, ROCm voit deux GPU : l'iGPU (souvent device 0, non pris en
  charge : ComfyUI plante dès le premier calcul) et la carte dédiée. Le script demande à PyTorch la liste des GPU,
  retient celui de l'architecture voulue (ou celui qui a le plus de mémoire) et modifie le lanceur.
  L'original est gardé dans Launch_ComfyUI.bat.bak-origine. Relancer le script ne change rien si c'est déjà fait.

.PARAMETER Gfx
  Architecture à retenir (ex. gfx1201). Par défaut : le GPU qui a le plus de mémoire.

.PARAMETER Index
  Forcer le numéro du GPU (sans interroger PyTorch).
#>
param([string]$Gfx, [int]$Index = -1)
. "$PSScriptRoot\commun.ps1"

Etape 'Choix du GPU pour ComfyUI'
if (-not (Test-Path $Lanceur)) { Echec "Lanceur introuvable : $Lanceur"; exit 1 }

if ($Index -lt 0) {
    $opt = @("$PSScriptRoot\detecter_gpu.py") + $(if ($Gfx) { @('--gfx', $Gfx) } else { @() })
    Invoke-PythonVenv @opt
    if ($LASTEXITCODE -ne 0) { Echec 'Détection impossible (PyTorch installé ? cf. 2-installer-pytorch-rocm10.ps1).'; exit 1 }
    $optIndex = $opt + '--index-seul'
    $sortie = Invoke-PythonVenv @optIndex
    if ($LASTEXITCODE -ne 0 -or "$sortie".Trim() -notmatch '^\d+$') { Echec "Numéro de GPU illisible : $sortie"; exit 1 }
    $Index = [int]"$sortie".Trim()
}

$texte = [IO.File]::ReadAllText($Lanceur)
$nouveau = $texte -replace "'main\.py( --cuda-device \d+)?'", "'main.py --cuda-device $Index'"
if ($nouveau -eq $texte) {
    if ($texte -match "'main\.py --cuda-device $Index'") { Ok "Launch_ComfyUI.bat utilise déjà le GPU $Index"; exit 0 }
    Echec "Ligne « 'main.py' » introuvable dans $Lanceur : lanceur d'un autre format, ajouter --cuda-device $Index à la main."
    exit 1
}
$sauvegarde = "$Lanceur.bak-origine"
if (-not (Test-Path $sauvegarde)) { Copy-Item $Lanceur $sauvegarde; Info "original sauvegardé : $sauvegarde" }
[IO.File]::WriteAllText($Lanceur, $nouveau)
Ok "Launch_ComfyUI.bat lance désormais ComfyUI avec --cuda-device $Index"
