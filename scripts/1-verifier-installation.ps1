<#
.SYNOPSIS
  Fait l'état des lieux : matériel, installation ComfyUI de l'AMD AI Bundle, PyTorch, lanceur, modèles, workflows.
  Ne modifie rien.
#>
. "$PSScriptRoot\commun.ps1"

Etape 'Matériel'
$cartes = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike '*Virtual*' -and $_.Name -notlike '*Basic*' }
foreach ($c in $cartes) { Info "$($c.Name)  (pilote $($c.DriverVersion))" }
if (-not ($cartes | Where-Object { $_.Name -like '*Radeon RX 9070*' })) {
    Attention "Pas de Radeon RX 9070 : ce dépôt a été mis au point sur cette carte. Lire docs\06-autre-configuration.md."
}
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
Info "RAM : $ram Go"
if ($ram -lt 30) { Attention 'Moins de 32 Go de RAM : SDXL passe, Qwen-Image-Edit (workflow 5) sera très lent ou impossible.' }
$disque = Get-PSDrive -Name ($env:LOCALAPPDATA.Substring(0, 1))
Info ("Espace libre sur {0}: : {1:N0} Go" -f $disque.Name, ($disque.Free / 1GB))

Etape 'ComfyUI (AMD AI Bundle)'
if (-not (Test-ComfyInstalle)) {
    Echec "ComfyUI introuvable dans $ComfyRacine"
    Info  "Installer l'AMD AI Bundle avec le composant ComfyUI (voir docs\02-installation.md, étape 1)."
    exit 1
}
$version = (Select-String -Path (Join-Path $ComfyDossier 'comfyui_version.py') -Pattern '__version__ = "(.+)"').Matches[0].Groups[1].Value
Ok "ComfyUI $version dans $ComfyRacine"
if ($version -ne '0.3.68') { Attention "Ce dépôt a été testé avec ComfyUI 0.3.68 (vous avez $version)." }

Etape 'PyTorch du venv de ComfyUI'
$torch = & $VenvPython -c "import torch; print(torch.__version__)" 2>$null
if ($torch -like '*rocm10*') { Ok "torch $torch" }
else { Attention "torch $torch : version livrée par AMD, sans kernels pour la RX 9070 -> lancer 2-installer-pytorch-rocm10.ps1" }

Etape 'Lanceur'
if (Select-String -Path $Lanceur -Pattern '--cuda-device' -Quiet) {
    $dev = (Select-String -Path $Lanceur -Pattern 'main\.py --cuda-device (\d+)').Matches[0].Groups[1].Value
    Ok "Launch_ComfyUI.bat lance ComfyUI sur le GPU $dev"
} else { Attention 'Launch_ComfyUI.bat ne choisit pas le GPU (l''iGPU risque d''être pris) -> lancer 3-configurer-lanceur.ps1' }

Etape 'Modèles (présence et taille, sans SHA256)'
Invoke-PythonVenv "$PSScriptRoot\telecharger_modeles.py" --comfyui $ComfyDossier --verifier --rapide tout

Etape 'Workflows'
$dest = Join-Path $ComfyDossier 'user\default\workflows'
foreach ($w in Get-ChildItem "$DepotRacine\workflows\*.json") {
    if (Test-Path (Join-Path $dest $w.Name)) { Ok $w.BaseName } else { Attention "$($w.BaseName) absent -> 5-installer-workflows.ps1" }
}

Etape 'Serveur'
if (Test-ComfyRepond) { Ok "ComfyUI répond sur $UrlComfy" } else { Info "ComfyUI n'est pas lancé (lancer-comfyui.ps1)." }
