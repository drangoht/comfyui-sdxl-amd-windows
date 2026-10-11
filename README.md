# Stable Diffusion en local avec ComfyUI sur Windows et une carte AMD (Radeon RX 9070)

Installation **locale, gratuite et hors ligne** (une fois les modèles téléchargés) de Stable Diffusion XL et de
Qwen-Image-Edit dans **ComfyUI**, sur Windows 11 avec une **Radeon RX 9070**. Le dépôt contient :

- des **scripts** qui installent et corrigent tout (PyTorch ROCm, choix du GPU, modèles vérifiés par SHA256, workflows) ;
- **5 workflows prêts à l'emploi**, commentés en français ;
- un **test de bout en bout** qui rejoue toute l'installation sur une copie et exécute les 5 workflows ;
- la **documentation** de ce qui a été fait et pourquoi.

![Texte → image : workflow 1 dans ComfyUI](<images/captures/1 - SDXL texte vers image.png>)

> [!WARNING]
> **Cette installation correspond à MA configuration.** Elle a été mise au point et testée sur une seule machine :
>
> | | |
> |---|---|
> | Carte graphique | **AMD Radeon RX 9070** (RDNA 4, `gfx1201`, 16 Go) — pilote Adrenalin 32.0.31041 |
> | Processeur | AMD Ryzen 7 9800X3D, **avec graphiques intégrés** (iGPU `gfx1036`, vu par ROCm, à écarter) |
> | Mémoire | 32 Go |
> | Système | Windows 11 Pro |
> | ComfyUI | **0.3.68**, installé par l'**AMD AI Bundle** (AMD Install Manager) |
> | PyTorch | **2.13.0 + ROCm 10.0** (remplace le 2.12 + ROCm 7.14 livré avec ComfyUI) |
>
> Avec une autre carte (autre AMD, NVIDIA), une autre version de ComfyUI ou moins de mémoire, **il faudra
> sûrement adapter** : voir [docs/06-autre-configuration.md](docs/06-autre-configuration.md).

## Exemples

Toutes ces images ont été produites par les workflows du dépôt, sur la machine ci-dessus, avec les réglages par défaut.

| Texte → image (SDXL, 2048 px, ≈ 52 s) | | |
|---|---|---|
| ![renard](images/exemples/1-texte-renard.jpg) | ![chalet](images/exemples/1-texte-chalet-aquarelle.jpg) | ![robot](images/exemples/1-texte-robot-jardinier.jpg) |
| *a red fox sitting in a misty autumn forest…* | *a cozy wooden cabin by a mountain lake… watercolor* | *a cute small robot gardener… 3d render* |

| Image de départ | Image → image (≈ 20 s) | Retouche d'une zone (≈ 19 s) | Guidé par les contours (≈ 25 s) | Édition par instruction, Qwen (≈ 2,5 min) |
|---|---|---|---|---|
| ![départ](images/exemples/0-image-de-depart.jpg) | ![img2img](images/exemples/2-image-vers-image.jpg) | ![retouche](images/exemples/3-retouche-casquette.jpg) | ![controlnet](images/exemples/4-contours-chevalier.jpg) | ![qwen](images/exemples/5-qwen-port-mediterraneen.jpg) |
| scène générée par SDXL | « aquarelle » : pose et palette gardées | masque sur la tête → casquette rouge | même composition → chevalier sous la neige | « remplace la ville par un port méditerranéen » |

## Installation rapide

**Prérequis** : Windows 10/11, carte AMD RDNA 4 (ou cf. [autre configuration](docs/06-autre-configuration.md)),
pilote AMD Adrenalin récent, ≈ 30 Go libres (≈ 85 Go avec Qwen), connexion Internet pour le premier téléchargement.

1. **Installer ComfyUI avec l'AMD AI Bundle** (étape manuelle, 10 min) : [docs/02-installation.md](docs/02-installation.md#1-installer-comfyui-avec-lamd-ai-bundle).
2. **Récupérer ce dépôt** :
   ```bash
   git clone https://github.com/drangoht/comfyui-sdxl-amd-windows.git
   ```
3. **Tout installer** (PyTorch ROCm 10, choix du GPU, modèles SDXL + ControlNet ≈ 16 Go, workflows) :
   ```bash
   powershell -ExecutionPolicy Bypass -File scripts\installer.ps1
   ```
   Pour ajouter Qwen-Image-Edit (≈ 31 Go de plus) : `-Modeles tout`.
4. **Lancer ComfyUI** puis ouvrir l'onglet **Workflows** de la barre latérale :
   ```bash
   powershell -ExecutionPolicy Bypass -File scripts\lancer-comfyui.ps1
   ```
5. *(facultatif)* **Vérifier** que tout marche, ComfyUI lancé :
   ```bash
   powershell -ExecutionPolicy Bypass -File scripts\tester-installation.ps1
   ```

Chaque script peut aussi être lancé seul, et chaque étape est expliquée pour être faite à la main :
[docs/02-installation.md](docs/02-installation.md).

## Les workflows

| Workflow | Pour quoi faire | Modèles | Temps (RX 9070) |
|---|---|---|---|
| **1 - SDXL texte vers image** | Créer une image à partir d'une description | SDXL base + refiner, RealESRGAN x2 | ≈ 16 s en 1024, **≈ 52 s en 2048** |
| **2 - SDXL image vers image** | Changer le style d'une image en gardant sa composition | SDXL base | ≈ 20 s (1 Mpx) |
| **3 - SDXL retouche d'une zone** | Refaire une partie d'une image (masque) | SDXL base | ≈ 19 s |
| **4 - SDXL guidé par les contours** | Garder la structure exacte, changer tout le reste (ControlNet) | SDXL base, ControlNet Union ProMax | ≈ 25 s |
| **5 - Qwen édition par instruction** | « Remplace le décor par… », « mets la personne de l'image 2 dans… » | Qwen-Image-Edit-2511 + LoRA Lightning | ≈ 2,5 à 6 min |

Mode d'emploi détaillé, réglages et conseils : [docs/03-workflows.md](docs/03-workflows.md).

## Ce que corrigent les scripts

L'AMD AI Bundle installe ComfyUI en un clic, mais **sur RX 9070 il ne fonctionne pas tel quel** :

| Problème | Symptôme | Correction | Script |
|---|---|---|---|
| Le PyTorch livré (2.12 + ROCm 7.14) n'a pas de kernels pour `gfx1201` | `hipErrorInvalidImage` au premier calcul | PyTorch **2.13 + ROCm 10.0** et les paquets `*_device_gfx1201` d'AMD | `2-installer-pytorch-rocm10.ps1` |
| ROCm voit **deux GPU** : l'iGPU du Ryzen (device 0, non pris en charge) et la RX 9070 (device 1) | plantage dès la génération | `--cuda-device 1` dans `Launch_ComfyUI.bat` | `3-configurer-lanceur.ps1` |
| Qwen-Image-Edit-2511 est publié au format `fp8mixed`, trop récent pour ComfyUI 0.3.68 | « Promotion for Float8 Types is not supported » | conversion locale vers l'ancien format `scaled_fp8` (copie d'octets) | `telecharger_modeles.py` |
| Upscale 2048 lent (2 min/image) | VRAM saturée | RealESRGAN x2 + VAE en tuiles de 512 + affinage 6 pas → 52 s | workflow 1 |

L'histoire complète (diagnostics, impasses, mesures) : [docs/04-mise-au-point-avec-claude-code.md](docs/04-mise-au-point-avec-claude-code.md).

## Contenu du dépôt

```
scripts/
  installer.ps1                  tout, dans l'ordre (2 → 5)
  1-verifier-installation.ps1    état des lieux, ne modifie rien
  2-installer-pytorch-rocm10.ps1 PyTorch 2.13 + ROCm 10 dans le venv de ComfyUI (SHA256 vérifiés)
  3-configurer-lanceur.ps1       --cuda-device N dans Launch_ComfyUI.bat
  4-telecharger-modeles.ps1      modèles officiels (Hugging Face, GitHub), reprise, SHA256
  5-installer-workflows.ps1      workflows + images de départ dans ComfyUI
  lancer-comfyui.ps1             démarrer ComfyUI (option -PrioriteBasse)
  tester-installation.ps1        exécuter les workflows par l'API (graines fixes)
  executer_workflow.py           exécuter n'importe quel workflow .json par l'API, en ligne de commande
  telecharger_modeles.py         téléchargeur (bibliothèque standard Python)
  detecter_gpu.py                GPU vus par PyTorch / ROCm
  qwen_fp8mixed_vers_scaled.py   conversion du modèle Qwen pour ComfyUI 0.3.68
workflows/                       les 5 workflows (glisser un .json dans ComfyUI pour l'ouvrir)
entrees/                         images de départ des workflows 2 à 5 (générées par SDXL)
tests/
  tester-tout.ps1                test complet sur une copie de l'installation (voir ci-dessous)
  captures.py                    captures d'écran de la documentation (Chrome headless)
images/                          captures d'écran et exemples
docs/                            documentation
```

## Tester tout le dépôt en local

`tests\tester-tout.ps1` rejoue l'installation **comme sur une machine neuve, sans toucher à l'installation réelle** :
il copie l'installation ComfyUI dans `.test\`, la remet dans l'état « sortie de l'AMD Install Manager » (et vérifie que
le problème d'origine `hipErrorInvalidImage` est bien là), lance `scripts\installer.ps1` dessus, démarre la copie sur le
port 8189 et exécute les workflows, puis supprime la copie.

```bash
powershell -ExecutionPolicy Bypass -File tests\tester-tout.ps1 -AvecQwen
```

Durée ≈ 8 min sur la machine de référence. Les images obtenues sont **identiques au pixel près** à celles de
`images\exemples\` (mêmes graines) : l'installation est reproductible. Détails : [docs/02-installation.md](docs/02-installation.md#tester-tout-en-local).

## Mis au point avec Claude Code

L'installation, les correctifs, les workflows, les mesures de performance, les scripts et cette documentation ont été
réalisés en octobre 2026 avec **[Claude Code](https://claude.com/claude-code)** (Anthropic), l'agent de programmation, dans
l'application de bureau Claude, par dialogue avec le propriétaire de la machine : Claude Code diagnostiquait (journaux,
versions, tests par l'API de ComfyUI), proposait, et demandait confirmation avant chaque téléchargement ou modification.
Le récit : [docs/04-mise-au-point-avec-claude-code.md](docs/04-mise-au-point-avec-claude-code.md).

## Références et licences

Les scripts, workflows et la documentation de ce dépôt sont sous **licence MIT** ([LICENSE](LICENSE)).
**Aucun modèle n'est redistribué ici** : ils sont téléchargés depuis leurs sources officielles et restent soumis à
leur propre licence (SDXL : CreativeML Open RAIL++-M ; ControlNet Union, Qwen-Image-Edit, LoRA Lightning : Apache 2.0 ;
Real-ESRGAN : BSD-3-Clause). Liste complète des outils, bibliothèques et modèles avec versions et liens :
[docs/references.md](docs/references.md).
