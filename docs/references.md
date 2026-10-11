# Références : outils, bibliothèques et modèles

Versions effectivement utilisées sur la [configuration de référence](01-ma-configuration.md) (octobre 2026).
Aucun de ces logiciels ou modèles n'est redistribué dans ce dépôt : ils sont installés ou téléchargés depuis leur source.

## Outils

| Outil | Version | Rôle | Licence | Lien |
|---|---|---|---|---|
| ComfyUI | 0.3.68 | interface à nœuds et serveur de génération | GPL-3.0 | https://github.com/comfyanonymous/ComfyUI |
| ComfyUI frontend | 1.28.8 (`comfyui_frontend_package`) | interface web | GPL-3.0 | https://github.com/Comfy-Org/ComfyUI_frontend |
| AMD Software: Adrenalin Edition | 32.0.31041.1004 | pilote graphique (ROCm sous Windows passe par lui) | propriétaire AMD | https://www.amd.com/fr/support/download/drivers.html |
| AMD Install Manager / AMD AI Bundle | composant ComfyUI 0.3.68 du 12/09/2026 | installe ComfyUI, Python embarqué, Git (et le composant PyTorch dont viennent les wheels ROCm 10) | conditions AMD | livré avec le pilote ; doc PyTorch/ROCm Windows citée par son manifeste : https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installrad/windows/install-pytorch.html |
| ROCm pour Windows (Radeon) | 10.0.0 (wheels Python) | pile de calcul GPU d'AMD | MIT / licences AMD | https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/ |
| Python | 3.12.10 (embarqué par l'AI Bundle) | exécute ComfyUI et les scripts | PSF | https://www.python.org/ |
| Git pour Windows | 2.51.2 (embarqué par l'AI Bundle) | — | GPL-2.0 | https://gitforwindows.org/ |
| Windows PowerShell | 5.1 | scripts d'installation | — | intégré à Windows |
| curl | intégré à Windows | téléchargement des wheels AMD | curl | https://curl.se/ |
| Google Chrome (ou Microsoft Edge) | — | captures d'écran (`tests\captures.py`, mode headless) | — | — |
| Claude Code | — | mise au point de l'installation, scripts, documentation | — | https://claude.com/claude-code |

## Bibliothèques Python (venv de ComfyUI)

PyTorch et ROCm viennent des dépôts d'AMD (`https://stable.repo.amd.com/rocm/…`) ; le reste a été installé par
l'AMD AI Bundle depuis PyPI selon `requirements.txt` de ComfyUI.

| Paquet | Version | Rôle | Licence |
|---|---|---|---|
| torch | 2.13.0+rocm10.0.0 | calcul sur GPU | BSD-3-Clause |
| amd-torch-device-gfx1201 | 2.13.0+rocm10.0.0 | kernels PyTorch pour la RX 9070 | AMD |
| torchvision | 0.28.0+rocm10.0.0 (+ `amd-torchvision-device-gfx1201`) | opérations sur images | BSD-3-Clause |
| torchaudio | 2.11.0.2+rocm10.0.0 | audio (requis par ComfyUI) | BSD-2-Clause |
| rocm, rocm-sdk-core, rocm-sdk-libraries, rocm-sdk-devel | 10.0.0 | runtime et bibliothèques ROCm | MIT / AMD |
| rocm-sdk-device-gfx1201 | 10.0.0 | bibliothèques ROCm compilées pour `gfx1201` | AMD |
| rocm-bootstrap | 0.2.0 | chargement de ROCm | AMD |
| torchsde | 0.2.6 | échantillonneurs stochastiques | Apache-2.0 |
| numpy | 2.5.3 | calcul numérique | BSD-3-Clause |
| scipy | 1.18.1 | calcul scientifique | BSD-3-Clause |
| pillow | 12.3.0 | lecture/écriture d'images | MIT-CMU |
| safetensors | 0.8.0 | format des fichiers de modèles | Apache-2.0 |
| transformers | 5.17.0 | encodeurs de texte | Apache-2.0 |
| tokenizers | 0.23.2 | découpage du texte | Apache-2.0 |
| sentencepiece | 0.2.2 | découpage du texte | Apache-2.0 |
| einops | 0.8.2 | manipulation de tenseurs | MIT |
| spandrel | 0.4.2 | chargement des modèles d'upscale (RealESRGAN) | MIT |
| kornia | 0.8.3 | traitements d'images (Canny…) | Apache-2.0 |
| aiohttp / yarl | 3.14.3 / 1.24.5 | serveur web et API de ComfyUI | Apache-2.0 |
| PyYAML | 6.0.3 | `extra_model_paths.yaml` (aussi lu par `telecharger_modeles.py`) | MIT |
| av | 18.1.0 | vidéo (FFmpeg) | BSD-3-Clause |
| SQLAlchemy / alembic | 2.0.52 / 1.20.0 | base interne de ComfyUI | MIT |
| pydantic / pydantic-settings | 2.13.5 / 2.15.0 | configuration | MIT |
| psutil | 7.2.2 | mémoire système | BSD-3-Clause |
| tqdm | 4.70.1 | barres de progression | MIT / MPL-2.0 |

Les scripts du dépôt n'ajoutent **aucune dépendance** : Python bibliothèque standard (+ PyYAML déjà présent) et PowerShell 5.1.

## Modèles

| Modèle | Fichier | Taille | SHA256 (début) | Licence | Source |
|---|---|---|---|---|---|
| Stable Diffusion XL 1.0 base | `sd_xl_base_1.0.safetensors` | 6,94 Go | `31e35c80…` | CreativeML Open RAIL++-M | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 |
| Stable Diffusion XL 1.0 refiner | `sd_xl_refiner_1.0.safetensors` | 6,08 Go | `7440042b…` | CreativeML Open RAIL++-M | https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0 |
| Real-ESRGAN x2plus | `RealESRGAN_x2plus.pth` | 67 Mo | `49fafd45…` | BSD-3-Clause | https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.1 |
| ControlNet Union SDXL 1.0 (ProMax) | `diffusion_pytorch_model_promax.safetensors` → `controlnet-union-sdxl-promax.safetensors` | 2,51 Go | `9fae2e50…` | Apache-2.0 | https://huggingface.co/xinsir/controlnet-union-sdxl-1.0 |
| Qwen-Image-Edit-2511 (version ComfyUI, fp8mixed) | `qwen_image_edit_2511_fp8mixed.safetensors` → converti en `qwen_image_edit_2511_scaled_fp8.safetensors` | 20,5 Go | `c9fdc158…` → `21f748fc…` | Apache-2.0 | https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI (modèle d'origine : https://huggingface.co/Qwen/Qwen-Image-Edit-2511) |
| Qwen2.5-VL 7B (encodeur de texte, fp8) | `qwen_2.5_vl_7b_fp8_scaled.safetensors` | 9,38 Go | `cb5636d8…` | Apache-2.0 | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI |
| VAE Qwen-Image | `qwen_image_vae.safetensors` | 0,25 Go | `a70580f0…` | Apache-2.0 | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI |
| Qwen-Image-Edit-2511 Lightning (LoRA 4 pas) | `Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | 0,85 Go | `22226e8d…` | Apache-2.0 | https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning |

SHA256 complets : `scripts\telecharger_modeles.py`. La licence CreativeML Open RAIL++-M de SDXL autorise l'usage, y compris
commercial, des images produites, avec des restrictions d'usage (pas de contenus illégaux, nuisibles, de désinformation…) :
la lire avant usage.

## Images du dépôt

- `entrees\test_img2img.png` et `entrees\test_inpaint.png` (même scène, zone de la tête rendue transparente pour la retouche)
  ont été **générées avec SDXL** sur la machine de référence.
- `images\exemples\` : produites par les workflows du dépôt (graines fixes, voir `scripts\tester-installation.ps1`),
  réduites en JPEG 1024 px.
- `images\captures\` : captures de l'interface ComfyUI par `tests\captures.py`.
