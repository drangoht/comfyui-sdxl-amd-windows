<#
.SYNOPSIS
  Remplace, dans le venv du ComfyUI de l'AMD AI Bundle, le PyTorch livré (2.12 + ROCm 7.14, sans kernels pour la
  RX 9070 -> « hipErrorInvalidImage ») par PyTorch 2.13 + ROCm 10.0 avec les paquets propres à l'architecture du GPU.

.DESCRIPTION
  Les wheels sont celles du composant « PyTorch » de l'AMD AI Bundle. Si l'AMD Install Manager les a déjà téléchargées
  (C:\Program Files\AMD\AMDInstallManager\DownloadedFiles), elles sont reprises ; sinon elles sont téléchargées depuis
  stable.repo.amd.com (≈ 1,8 Go). Chaque fichier est vérifié par SHA256.
  L'état d'avant est sauvegardé dans venv-freeze-avant-rocm10.txt (pour revenir en arrière, cf. docs\05-depannage.md).

.PARAMETER Gfx
  Architecture du GPU : gfx1201 (RX 9070 / 9070 XT, défaut), gfx1200 (RX 9060 XT), gfx1151 (Ryzen AI Max « Strix Halo »).

.PARAMETER Simulation
  Montre ce que pip ferait (pip --dry-run), sans rien installer.
#>
param(
    [ValidateSet('gfx1201', 'gfx1200', 'gfx1151')][string]$Gfx = 'gfx1201',
    [switch]$Simulation
)
. "$PSScriptRoot\commun.ps1"

$Base = 'https://stable.repo.amd.com/rocm'
# Fichier => (URL, SHA256) — valeurs du manifeste de l'AMD Install Manager (AIBundle.json, composant PyTorch 2.13.0)
$Communs = [ordered]@{
    'rocm_sdk_core-10.0.0-py3-none-win_amd64.whl'      = "$Base/core/whl-next/rocm-sdk-core", '066195cb0f7df02e6009facb17652dd992d13fae44d87652e5ab928d5b4f0851'
    'rocm_sdk_libraries-10.0.0-py3-none-win_amd64.whl' = "$Base/core/whl-next/rocm-sdk-libraries", 'bfc7a1bd3b6050fb4d36d8ac2eea80d3afd70c5604a29142463d6cb890fc73bf'
    'rocm_sdk_devel-10.0.0-py3-none-win_amd64.whl'     = "$Base/core/whl-next/rocm-sdk-devel", '3ca92d4af9b31113ec21f826c8e5a7f1c30a702438f6e9dc98bceb0fccd95993'
    'rocm-10.0.0.tar.gz'                               = "$Base/core/whl-next/rocm", '65b5982249612a310135f5e061b9f28909e8ad718a1ddb3f1abba92298b7216b'
    'torch-2.13.0+rocm10.0.0-cp312-cp312-win_amd64.whl'       = "$Base/pytorch/whl-next/torch", '4ff21da558065d6c28773f9053eadec4897c579e1f34f623db3825755198b164'
    'torchvision-0.28.0+rocm10.0.0-cp312-cp312-win_amd64.whl' = "$Base/pytorch/whl-next/torchvision", 'ecf20b27fba1b8e189c029be01b984f3a582053c67e5e35f27e3b83a3202b819'
    'torchaudio-2.11.0.2+rocm10.0.0-cp312-cp312-win_amd64.whl' = "$Base/pytorch/whl-next/torchaudio", '25c1857654c9232474bd88da29f91979482d243a2b096e0b22381c4e6bd65cf5'
}
$ParGfx = @{
    gfx1201 = [ordered]@{
        'rocm_sdk_device_gfx1201-10.0.0-py3-none-win_amd64.whl'                   = "$Base/core/whl-next/rocm-sdk-device-gfx1201", 'c6e4c5a0da941230bed975765e644597570081c9a41654d5a052c277167f4576'
        'amd_torch_device_gfx1201-2.13.0+rocm10.0.0-cp312-cp312-win_amd64.whl'       = "$Base/pytorch/whl-next/amd-torch-device-gfx1201", '35774bfcb9bdb5dfbef57bd799d0993ab16b9e454b5a140dd1eb24249bf40ee6'
        'amd_torchvision_device_gfx1201-0.28.0+rocm10.0.0-cp312-cp312-win_amd64.whl' = "$Base/pytorch/whl-next/amd-torchvision-device-gfx1201", '76c93771ad26a0846b291d72888030be61d724581159c88109c03d5897acc9cd'
    }
    gfx1200 = [ordered]@{
        'rocm_sdk_device_gfx1200-10.0.0-py3-none-win_amd64.whl'                   = "$Base/core/whl-next/rocm-sdk-device-gfx1200", 'f33226078932ee2200f5595c521895edf5d7abf3170975d8c6f72a2a3949f516'
        'amd_torch_device_gfx1200-2.13.0+rocm10.0.0-cp312-cp312-win_amd64.whl'       = "$Base/pytorch/whl-next/amd-torch-device-gfx1200", '3122981c6269a8d10233e58aa2f49bad4af9f10dcb4b35cb6db4d83da4d4fb1b'
        'amd_torchvision_device_gfx1200-0.28.0+rocm10.0.0-cp312-cp312-win_amd64.whl' = "$Base/pytorch/whl-next/amd-torchvision-device-gfx1200", '7f86931a15f41a1bb12b7b19e824604d9aa54a2107931c448bc2aa15ad550417'
    }
    gfx1151 = [ordered]@{
        'rocm_sdk_device_gfx1151-10.0.0-py3-none-win_amd64.whl'                   = "$Base/core/whl-next/rocm-sdk-device-gfx1151", '1ab27ebfe61ea3c3fd2c5c1a0e780ae22ed9b662106ce0aefda0a30e3b11577f'
        'amd_torch_device_gfx1151-2.13.0+rocm10.0.0-cp312-cp312-win_amd64.whl'       = "$Base/pytorch/whl-next/amd-torch-device-gfx1151", 'd274a50cfab1943b4fec390db48ae3faa4bcfe1653ccc17812a373ac2ac7fa6f'
        'amd_torchvision_device_gfx1151-0.28.0+rocm10.0.0-cp312-cp312-win_amd64.whl' = "$Base/pytorch/whl-next/amd-torchvision-device-gfx1151", '38876c528dcc83d069626bf6faff0586be94c38e2cc59f9eee299b5fbdf270bb'
    }
}

Etape "PyTorch 2.13 + ROCm 10 pour $Gfx"
if (-not (Test-ComfyInstalle)) { Echec "ComfyUI introuvable dans $ComfyRacine (installer d'abord l'AMD AI Bundle)."; exit 1 }
if (-not $Simulation -and (Get-ComfyProcessus)) { Echec 'ComfyUI est en cours d''exécution : le fermer d''abord (ses DLL torch sont verrouillées).'; exit 1 }

$Local = 'C:\Program Files\AMD\AMDInstallManager\DownloadedFiles'
$Cache = Join-Path $env:LOCALAPPDATA 'comfyui-sdxl-amd-windows\wheels'
New-Item -ItemType Directory -Force $Cache | Out-Null

$fichiers = @()
$tous = [ordered]@{}; $Communs.GetEnumerator() | ForEach-Object { $tous[$_.Key] = $_.Value }; $ParGfx[$Gfx].GetEnumerator() | ForEach-Object { $tous[$_.Key] = $_.Value }
foreach ($nom in $tous.Keys) {
    $url = $tous[$nom][0] + '/' + [uri]::EscapeDataString($nom)
    $sha = $tous[$nom][1]
    $chemin = $null
    foreach ($c in @((Join-Path $Local $nom), (Join-Path $Cache $nom))) {
        if ((Test-Path $c) -and (Get-FileHash $c -Algorithm SHA256).Hash -eq $sha) { $chemin = $c; break }
    }
    if ($chemin) { Ok "$nom (déjà présent : $(Split-Path $chemin))" }
    else {
        $chemin = Join-Path $Cache $nom
        Info "téléchargement de $nom…"
        curl.exe -L -f -s -S -C - --retry 5 -o "$chemin" "$url"
        if ($LASTEXITCODE -ne 0) { Echec "échec du téléchargement : $url"; exit 1 }
        if ((Get-FileHash $chemin -Algorithm SHA256).Hash -ne $sha) { Remove-Item $chemin; Echec "SHA256 incorrect pour $nom"; exit 1 }
        Ok "$nom (téléchargé, SHA256 vérifié)"
    }
    $fichiers += $chemin
}

$sauvegarde = Join-Path $ComfyRacine 'venv-freeze-avant-rocm10.txt'
if (-not (Test-Path $sauvegarde)) {
    & $VenvPython -m pip freeze | Set-Content -Encoding utf8 $sauvegarde
    Ok "état actuel du venv sauvegardé : $sauvegarde"
}

Etape ($(if ($Simulation) { 'pip install --dry-run (simulation)' } else { 'pip install' }))
$args_pip = @('-m', 'pip', 'install', '--disable-pip-version-check') + $(if ($Simulation) { @('--dry-run') } else { @() }) + $fichiers
& $VenvPython @args_pip
if ($LASTEXITCODE -ne 0) { Echec 'pip a échoué.'; exit 1 }

if (-not $Simulation) {
    Etape 'Contrôle'
    Invoke-PythonVenv "$PSScriptRoot\detecter_gpu.py" --gfx $Gfx
}
