<#
.SYNOPSIS
  Test complet du dépôt, sans toucher à l'installation réelle :
    1. copie l'installation ComfyUI de l'AMD AI Bundle dans .test\ (≈ 7 Go ; les modèles sont reliés, pas copiés) ;
    2. remet la copie dans l'état « sortie de l'AMD Install Manager » : PyTorch 2.12 + ROCm 7.14, lanceur d'origine ;
       et vérifie que ce PyTorch ne sait effectivement pas calculer sur la carte (le problème d'origine) ;
    3. joue scripts\installer.ps1 sur la copie, comme un nouvel utilisateur ;
    4. démarre la copie sur un autre port (8189) avec les options écrites dans son lanceur ;
    5. exécute les workflows (scripts\tester-installation.ps1), puis arrête la copie et la supprime.

.PARAMETER AvecQwen
  Teste aussi le workflow 5 (modèles Qwen requis).

.PARAMETER AvecTelechargement
  Laisse installer.ps1 télécharger les modèles manquants (sinon il vérifie seulement leur présence et leur SHA256).

.PARAMETER GarderCopie
  Ne supprime pas la copie à la fin (pour l'examiner).

.PARAMETER Forcer
  Lance le test même si un autre ComfyUI tourne (déconseillé : la mémoire de la carte est partagée).
#>
param([switch]$AvecQwen, [switch]$AvecTelechargement, [switch]$GarderCopie, [switch]$Forcer, [int]$Port = 8189)

$env:COMFYUI_RACINE = $null
. "$PSScriptRoot\..\scripts\commun.ps1"
$Source = $ComfyRacine                                   # installation réelle (lue, jamais modifiée)
$Copie  = Join-Path $DepotRacine '.test\ComfyUI'
$Journal = Join-Path $DepotRacine '.test\comfyui-copie.log'
$debut = Get-Date

function Supprimer-Copie {
    if (-not (Test-Path $Copie)) { return }
    $lien = Join-Path $Copie 'ComfyUI\models'
    # Le dossier models de la copie est une jonction vers celui de l'installation réelle :
    # la retirer seule AVANT tout effacement récursif, sinon on effacerait les vrais modèles.
    if ((Test-Path $lien) -and ((Get-Item $lien -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        [IO.Directory]::Delete($lien)
    }
    cmd /c rmdir /s /q "`"$Copie`""
}

# ---------------------------------------------------------------------------------------------------------------
Etape '0. Préalables'
if (-not (Test-Path (Join-Path $Source 'ComfyUI\main.py'))) { Echec "Installation source introuvable : $Source"; exit 1 }
if ((Test-ComfyRepond) -and -not $Forcer) {
    Echec "Un ComfyUI tourne déjà sur $UrlComfy : l'arrêter (il occupe la mémoire de la carte) ou relancer avec -Forcer."
    exit 1
}
$wheels = 'C:\Program Files\AMD\AMDInstallManager\DownloadedFiles'
# PyTorch d'origine du composant ComfyUI de l'AMD AI Bundle (AIBundle.json) — sert à recréer l'état « avant correction »
$Origine = [ordered]@{
    'rocm_sdk_core-7.14.0-py3-none-win_amd64.whl'              = 'e0d5650b9b6ff931496d3336eb72cb969fb3bc4e1966dc84b80b727af32a6bf0'
    'rocm_sdk_devel-7.14.0-py3-none-win_amd64.whl'             = '9d28c9c67f719869b73cc5fbf6d5dbe44fcf17f3aab5e37c4a7efa0b59c153af'
    'rocm_sdk_libraries-7.14.0-py3-none-win_amd64.whl'         = 'd03873d2879c000ae307866cc827fe76d6e9f50846fec76b7cb293202afdee56'
    'rocm-7.14.0.tar.gz'                                       = '77c622d8eef7bf7fa1af70d410a05a621abbd2baaf53e52ab268dc6d140e15b2'
    'torch-2.12.0+rocm7.14.0-cp312-cp312-win_amd64.whl'        = 'b2ba179797cf065580e32d38279428f6fd411552a63baf8c2f7145fec922a142'
    'torchvision-0.27.0+rocm7.14.0-cp312-cp312-win_amd64.whl'  = 'fc0e5c9f1d889b6a7be38b949700472f2086b5113a87457ba4480a76fe6d79e2'
    'torchaudio-2.11.0+rocm7.14.0-cp312-cp312-win_amd64.whl'   = '5e56f78e4ca9c0dd64f61cb927efbb3dd1a42adcf723affd6ce3bdf9ec9cdd39'
}
$fichiersOrigine = @()
foreach ($nom in $Origine.Keys) {
    $chemin = Join-Path $wheels $nom
    if (-not (Test-Path $chemin)) {
        $chemin = Join-Path $env:LOCALAPPDATA "comfyui-sdxl-amd-windows\wheels\$nom"
        if (-not (Test-Path $chemin)) {
            New-Item -ItemType Directory -Force (Split-Path $chemin) | Out-Null
            Info "téléchargement de $nom (état d'origine)…"
            curl.exe -L -f -s -S -o "$chemin" ("https://repo.radeon.com/rocm/windows/.rocm-rel-7.14_a/" + [uri]::EscapeDataString($nom))
        }
    }
    if ((Get-FileHash $chemin -Algorithm SHA256).Hash -ne $Origine[$nom]) { Echec "SHA256 incorrect : $chemin"; exit 1 }
    $fichiersOrigine += $chemin
}
Ok 'wheels de l''état d''origine disponibles'

# ---------------------------------------------------------------------------------------------------------------
Etape '1. Copie de l''installation'
Supprimer-Copie
New-Item -ItemType Directory -Force $Copie | Out-Null
foreach ($d in 'Python', 'venv') {
    robocopy (Join-Path $Source $d) (Join-Path $Copie $d) /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
    if ($LASTEXITCODE -ge 8) { Echec "copie de $d impossible"; exit 1 }
}
# Dossiers de données exclus par chemin complet : « /XD models » exclurait aussi comfy\ldm\models (code de ComfyUI)
$exclus = 'models', 'output', 'input', 'user', 'temp', '.git' | ForEach-Object { Join-Path $Source "ComfyUI\$_" }
robocopy (Join-Path $Source 'ComfyUI') (Join-Path $Copie 'ComfyUI') /E /XD @exclus __pycache__ /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -ge 8) { Echec 'copie de ComfyUI impossible'; exit 1 }
cmd /c mklink /J "`"$Copie\ComfyUI\models`"" "`"$Source\ComfyUI\models`"" | Out-Null
# pyvenv.cfg du venv copié : pointer sur le Python copié
$cfg = Join-Path $Copie 'venv\pyvenv.cfg'
(Get-Content $cfg) -replace [regex]::Escape($Source), $Copie | Set-Content -Encoding ascii $cfg
# Lanceur d'origine (AMD), réécrit pour la copie
$lanceurOrigine = if (Test-Path "$Source\Launch_ComfyUI.bat.bak-origine") { "$Source\Launch_ComfyUI.bat.bak-origine" } else { "$Source\Launch_ComfyUI.bat" }
$motif = [regex]::Escape($Source)                         # -replace ignore la casse (« ai_bundle » / « AI_Bundle »)
$texte = [IO.File]::ReadAllText($lanceurOrigine)
$texte = $texte -replace $motif, $Copie
$texte = $texte -replace ' --cuda-device \d+', ''
[IO.File]::WriteAllText("$Copie\Launch_ComfyUI.bat", $texte)
Ok ("copie prête : {0:N1} Go" -f ((Get-ChildItem $Copie -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "$Copie\ComfyUI\models\*" } | Measure-Object Length -Sum).Sum / 1GB))

# Tout ce qui suit vise la copie
$env:COMFYUI_RACINE = $Copie
. "$PSScriptRoot\..\scripts\commun.ps1"

# ---------------------------------------------------------------------------------------------------------------
Etape '2. Retour à l''état d''origine (PyTorch 2.12 + ROCm 7.14 livré par AMD)'
$ErrorActionPreference = 'Continue'   # pip et python écrivent sur stderr : sous PowerShell 5.1, ce n'est pas une erreur
& $VenvPython -m pip uninstall -y --disable-pip-version-check amd-torch-device-gfx1201 amd-torchvision-device-gfx1201 rocm-sdk-device-gfx1201 amd-torch-device-gfx1200 amd-torchvision-device-gfx1200 rocm-sdk-device-gfx1200 2>&1 | Out-Null
& $VenvPython -m pip install --disable-pip-version-check -q @fichiersOrigine
if ($LASTEXITCODE -ne 0) { Echec 'réinstallation de l''état d''origine impossible'; exit 1 }
$v = & $VenvPython -c "import torch; print(torch.__version__)"
Ok "torch $v"
$essai = & $VenvPython -c "import torch; n=max(range(torch.cuda.device_count()), key=lambda i: torch.cuda.get_device_properties(i).total_memory); print((torch.ones(4, device=f'cuda:{n}') * 2).sum().item())" 2>&1 | Out-String
if ($essai -match 'hipError') { Ok ('problème d''origine reproduit : ' + ([regex]::Match($essai, 'hipError\w+').Value)) }
else { Attention "le PyTorch d'origine calcule sur la carte ? ($($essai.Trim()))" }
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------------------------------------------
Etape '3. scripts\installer.ps1 sur la copie'
$groupes = if ($AvecQwen) { @('tout') } else { @('sdxl', 'controlnet') }
& "$DepotRacine\scripts\installer.ps1" -Modeles $groupes -SansTelechargement:(-not $AvecTelechargement)
if ($LASTEXITCODE -ne 0) { Echec 'installer.ps1 a échoué'; exit 1 }
& "$DepotRacine\scripts\1-verifier-installation.ps1"

# ---------------------------------------------------------------------------------------------------------------
Etape "4. Démarrage de la copie (port $Port)"
$m = [regex]::Match([IO.File]::ReadAllText($Lanceur), "'main\.py --cuda-device (\d+)'")
if (-not $m.Success) { Echec 'le lanceur de la copie ne contient pas --cuda-device'; exit 1 }
Ok "lanceur configuré : --cuda-device $($m.Groups[1].Value)"
$env:PYTHONPATH = Join-Path $Copie 'Python'
$proc = Start-Process $VenvPython -ArgumentList "main.py --cuda-device $($m.Groups[1].Value) --port $Port" -WorkingDirectory $ComfyDossier `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $Journal -RedirectStandardError "$Journal.err"
$env:PYTHONPATH = $null
$UrlComfy = "http://127.0.0.1:$Port"
for ($i = 0; $i -lt 180 -and -not (Test-ComfyRepond); $i++) { Start-Sleep 1 }
if (-not (Test-ComfyRepond)) { Echec "la copie ne répond pas (journal : $Journal.err)"; taskkill /PID $proc.Id /T /F | Out-Null; exit 1 }
$stats = Invoke-WebRequest "$UrlComfy/system_stats" -UseBasicParsing | ConvertFrom-Json
Ok ("ComfyUI {0}, PyTorch {1}, {2}" -f $stats.system.comfyui_version, $stats.system.pytorch_version, $stats.devices[0].name)

# ---------------------------------------------------------------------------------------------------------------
Etape '5. Workflows'
& "$DepotRacine\scripts\tester-installation.ps1" -Url $UrlComfy -AvecQwen:$AvecQwen
$resultat = $LASTEXITCODE

taskkill /PID $proc.Id /T /F | Out-Null
Start-Sleep 2
if (-not $GarderCopie) { Supprimer-Copie; Info 'copie supprimée' }

Etape 'Résultat'
if ($resultat -eq 0) { Ok ("TEST COMPLET RÉUSSI en {0:N0} min" -f ((Get-Date) - $debut).TotalMinutes) }
else { Echec 'au moins un workflow a échoué (voir ci-dessus)' }
exit $resultat
