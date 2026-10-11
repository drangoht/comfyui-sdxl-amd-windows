# 2. Installation pas à pas

Durée : ≈ 10 min de manipulations + le temps de téléchargement (≈ 16 Go pour SDXL et ControlNet, ≈ 31 Go de plus pour Qwen).
Configuration visée : celle de [01-ma-configuration.md](01-ma-configuration.md).

Résumé :

| Étape | Comment | Script |
|---|---|---|
| 1. Installer ComfyUI (AMD AI Bundle) | à la main, une fois | — |
| 2. PyTorch 2.13 + ROCm 10 | automatique | `2-installer-pytorch-rocm10.ps1` |
| 3. Choisir la carte graphique | automatique | `3-configurer-lanceur.ps1` |
| 4. Télécharger les modèles | automatique | `4-telecharger-modeles.ps1` |
| 5. Installer les workflows | automatique | `5-installer-workflows.ps1` |
| Tout 2 → 5 d'un coup | | **`installer.ps1`** |

> Les scripts sont des fichiers PowerShell. Windows bloque par défaut les scripts non signés : on les lance avec
> `powershell -ExecutionPolicy Bypass -File <script>` (ne change aucun réglage de la machine). Si le dépôt a été
> téléchargé en .zip plutôt que cloné, débloquer d'abord les fichiers : `Get-ChildItem -Recurse | Unblock-File`.

---

## 1. Installer ComfyUI avec l'AMD AI Bundle

L'**AMD AI Bundle** est un ensemble d'outils d'IA locale proposé par AMD avec son pilote (ComfyUI, PyTorch, LM Studio,
Ollama…). Il s'installe avec l'**AMD Install Manager**.

1. Installer ou mettre à jour le pilote **AMD Software: Adrenalin Edition** (https://www.amd.com/fr/support/download/drivers.html).
2. Ouvrir **AMD Install Manager** (menu Démarrer ; il est aussi proposé à la fin de l'installation du pilote).
3. Dans les composants d'IA (AI Bundle), cocher **ComfyUI** et installer. Il est inutile de cocher « PyTorch » : le script
   de l'étape 2 récupère lui-même les mêmes fichiers.
4. Résultat attendu : le dossier `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\` contenant `ComfyUI\`, `Python\`, `venv\`, `Git\`
   et `Launch_ComfyUI.bat`.

> ⚠ **Ne pas lancer ComfyUI tout de suite** : sur RX 9070, la version installée plante au premier calcul
> (`hipErrorInvalidImage`). C'est l'objet de l'étape 2.

Vérification (ne modifie rien) :

```bash
powershell -ExecutionPolicy Bypass -File scripts\1-verifier-installation.ps1
```

## 2. à 5. Tout le reste en une commande

ComfyUI fermé :

```bash
powershell -ExecutionPolicy Bypass -File scripts\installer.ps1
```

Options :

| Option | Effet |
|---|---|
| `-Modeles sdxl` | seulement SDXL (workflows 1 à 3), ≈ 13 Go |
| `-Modeles sdxl,controlnet` | défaut, workflows 1 à 4, ≈ 16 Go |
| `-Modeles tout` | avec Qwen-Image-Edit (workflow 5), ≈ 47 Go (+ 20,5 Go temporaires pendant la conversion) |
| `-Gfx gfx1200` | Radeon RX 9060 XT (`gfx1151` : Ryzen AI Max « Strix Halo ») — **non testé** |
| `-SansTelechargement` | ne télécharge pas : vérifie seulement les modèles déjà présents |

Le script s'arrête à la première erreur. On peut le relancer sans risque : chaque étape détecte ce qui est déjà fait.

Le détail de chaque étape, pour comprendre ou pour la faire à la main, suit.

---

## 2. PyTorch 2.13 + ROCm 10 dans le venv de ComfyUI

```bash
powershell -ExecutionPolicy Bypass -File scripts\2-installer-pytorch-rocm10.ps1
```

**Pourquoi** : le ComfyUI de l'AI Bundle 0.3.68 arrive avec `torch 2.12.0+rocm7.14.0`, compilé pour des architectures
génériques ne comprenant pas `gfx1201`. Le composant « PyTorch » du même AI Bundle, lui, fournit
`torch 2.13.0+rocm10.0.0` accompagné de paquets propres à chaque GPU (`amd_torch_device_gfx1201`…). On installe ce
second PyTorch dans le venv de ComfyUI.

**Ce que fait le script** :
1. réunit 10 fichiers (≈ 1,8 Go) : ceux déjà téléchargés par l'AMD Install Manager
   (`C:\Program Files\AMD\AMDInstallManager\DownloadedFiles`), sinon depuis `https://stable.repo.amd.com/rocm/…` ;
   chaque fichier est vérifié par **SHA256** (valeurs du manifeste `AIBundle.json` d'AMD) ;
2. sauvegarde la liste des paquets actuels dans `venv-freeze-avant-rocm10.txt` (retour arrière : [05-depannage.md](05-depannage.md)) ;
3. `python -m pip install` de ces fichiers dans le venv ;
4. affiche les GPU vus par le nouveau PyTorch.

**À la main** : avec le Python du venv (`%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\venv\Scripts\python.exe`),
`-m pip install` des fichiers `rocm_sdk_core`, `rocm_sdk_libraries`, `rocm_sdk_devel`, `rocm-10.0.0.tar.gz`,
`rocm_sdk_device_gfx1201`, `torch`, `torchvision`, `torchaudio`, `amd_torch_device_gfx1201`, `amd_torchvision_device_gfx1201`
(URL et SHA256 dans le script). `-Simulation` montre ce que pip ferait sans rien installer.

Résultat attendu :

```
PyTorch 2.13.0+rocm10.0.0 (HIP 7.15.26333)
  device 0 : AMD Radeon(TM) Graphics          gfx1036    12.2 Go
  device 1 : AMD Radeon RX 9070               gfx1201    15.9 Go   <- retenu
```

## 3. Lancer ComfyUI sur la bonne carte

```bash
powershell -ExecutionPolicy Bypass -File scripts\3-configurer-lanceur.ps1
```

**Pourquoi** : avec un processeur Ryzen à graphiques intégrés, ROCm expose l'iGPU en **device 0**. ComfyUI prend le
device 0 par défaut et plante. L'option `--cuda-device 1` de ComfyUI (le nom vient de CUDA mais vaut aussi pour ROCm)
désigne la RX 9070.

**Ce que fait le script** : demande la liste des GPU à PyTorch (`detecter_gpu.py`, sans aucun calcul sur l'iGPU), retient
celui de l'architecture voulue ou celui qui a le plus de mémoire, puis remplace `'main.py'` par
`'main.py --cuda-device 1'` dans `Launch_ComfyUI.bat`. L'original est gardé dans `Launch_ComfyUI.bat.bak-origine`.

**À la main** : ouvrir `Launch_ComfyUI.bat` dans un éditeur de texte et ajouter ` --cuda-device 1` après `main.py`.
Hors de ComfyUI, la variable d'environnement `HIP_VISIBLE_DEVICES=1` a le même effet.

## 4. Télécharger les modèles

```bash
powershell -ExecutionPolicy Bypass -File scripts\4-telecharger-modeles.ps1 -Groupes sdxl,controlnet
```

| Groupe | Fichiers (dossier de `ComfyUI\models\`) | Taille | Source |
|---|---|---|---|
| `sdxl` | `checkpoints\sd_xl_base_1.0.safetensors` | 6,9 Go | stabilityai/stable-diffusion-xl-base-1.0 |
| | `checkpoints\sd_xl_refiner_1.0.safetensors` | 6,1 Go | stabilityai/stable-diffusion-xl-refiner-1.0 |
| | `upscale_models\RealESRGAN_x2plus.pth` | 64 Mo | GitHub xinntao/Real-ESRGAN, release v0.2.1 |
| `controlnet` | `controlnet\controlnet-union-sdxl-promax.safetensors` | 2,5 Go | xinsir/controlnet-union-sdxl-1.0 (fichier `promax`) |
| `qwen` | `diffusion_models\qwen_image_edit_2511_scaled_fp8.safetensors` | 20,5 Go | Comfy-Org/Qwen-Image-Edit_ComfyUI, **converti** (voir ci-dessous) |
| | `text_encoders\qwen_2.5_vl_7b_fp8_scaled.safetensors` | 9,4 Go | Comfy-Org/Qwen-Image_ComfyUI |
| | `vae\qwen_image_vae.safetensors` | 0,25 Go | Comfy-Org/Qwen-Image_ComfyUI |
| | `loras\Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | 0,85 Go | lightx2v/Qwen-Image-Edit-2511-Lightning |

- Chaque fichier est contrôlé par **SHA256** (valeurs publiées par Hugging Face / mesurées sur la release GitHub).
- Un téléchargement interrompu **reprend** où il s'était arrêté (fichier `.part`) : relancer simplement le script.
- Un modèle déjà présent dans un dossier déclaré par `ComfyUI\extra_model_paths.yaml` (par exemple des modèles partagés
  avec une installation A1111, comme sur la machine de référence) est vérifié sur place et pas retéléchargé.
- `-Verifier` contrôle les fichiers sans rien télécharger.

**Qwen-Image-Edit-2511 et ComfyUI 0.3.68** : le fichier publié utilise une quantification (`fp8mixed`) apparue après la
0.3.68, qui plante (« Promotion for Float8 Types is not supported »). Le script le télécharge puis le convertit vers
l'ancien format `scaled_fp8` avec `qwen_fp8mixed_vers_scaled.py` : les tenseurs sont **recopiés octet pour octet** (rien
n'est recalculé), seuls leurs noms et l'en-tête changent ; le résultat est vérifié par SHA256 puis l'original est supprimé.
Avec un ComfyUI plus récent, cette conversion est inutile.

**À la main** : télécharger les fichiers depuis les pages Hugging Face / GitHub (liens dans [references.md](references.md))
et les ranger dans les dossiers indiqués.

## 5. Installer les workflows

```bash
powershell -ExecutionPolicy Bypass -File scripts\5-installer-workflows.ps1
```

Copie `workflows\*.json` dans `ComfyUI\user\default\workflows\` (onglet **Workflows** de ComfyUI) et `entrees\*.png`
dans `ComfyUI\input\` (images de départ par défaut des workflows 2 à 5). Un workflow modifié dans ComfyUI n'est pas
écrasé, sauf avec `-Force`.

**À la main** : glisser-déposer un fichier `.json` du dossier `workflows\` dans la page de ComfyUI l'ouvre directement.

---

## Lancer ComfyUI

```bash
powershell -ExecutionPolicy Bypass -File scripts\lancer-comfyui.ps1
```

ou double-clic sur `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\Launch_ComfyUI.bat`. Le navigateur s'ouvre sur
**http://127.0.0.1:8188**. Garder la fenêtre console ouverte : la fermer arrête ComfyUI.
`-PrioriteBasse` rend le PC plus réactif pendant les générations.

## Vérifier que tout marche

ComfyUI lancé :

```bash
powershell -ExecutionPolicy Bypass -File scripts\tester-installation.ps1
```

Exécute les workflows 1 à 4 par l'API (graines fixes) — ajouter `-AvecQwen` pour le 5 — et range les images dans
`sorties-test\`. Sur la configuration de référence, elles sont **identiques au pixel près** aux images de
`images\exemples\` (mêmes graines) ; sur une autre carte ou une autre version de PyTorch, elles seront proches mais pas identiques.

Pour exécuter un workflow quelconque en ligne de commande (traitement par lots, par exemple) :

```bash
python scripts\executer_workflow.py "workflows\1 - SDXL texte vers image.json" --prompt "a lighthouse at dawn" --seed 42 --sortie mes-images
```

(`--image` pour l'image de départ, `--regler "Titre du nœud:entrée=valeur"` pour un réglage ; détails : `--help`.)

## Tester tout en local

`tests\tester-tout.ps1` vérifie le dépôt entier **sans modifier l'installation réelle** :

```bash
powershell -ExecutionPolicy Bypass -File tests\tester-tout.ps1 -AvecQwen
```

1. **Copie** l'installation de l'AI Bundle dans `.test\ComfyUI` (≈ 7 Go ; le dossier `models` est une jonction vers
   l'original, rien n'est dupliqué) ;
2. la remet dans l'**état d'usine** : PyTorch 2.12 + ROCm 7.14 d'AMD, lanceur sans `--cuda-device` — et vérifie que le
   problème d'origine (`hipErrorInvalidImage`) est bien reproduit ;
3. joue **`scripts\installer.ps1`** sur la copie, puis `1-verifier-installation.ps1` ;
4. démarre la copie sur le **port 8189** avec les options écrites dans son lanceur ;
5. exécute les workflows (`tester-installation.ps1`), arrête la copie et la supprime.

Résultat sur la machine de référence (11/10/2026) : **réussi en 8 min**, problème d'origine reproduit puis corrigé,
5 workflows OK (64 s, 18 s, 19 s, 24 s, 134 s), images identiques au pixel près aux exemples.

Options : `-AvecTelechargement` (laisser l'installeur télécharger les modèles manquants), `-GarderCopie`, `-Forcer`
(si un autre ComfyUI tourne — déconseillé, la mémoire de la carte est partagée).

Les captures d'écran de la documentation se régénèrent avec `python tests\captures.py` (ComfyUI lancé ; Chrome ou Edge
piloté en mode headless, bibliothèque standard Python uniquement).
