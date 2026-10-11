# 6. Adapter à une autre configuration

Le dépôt a été testé **uniquement** sur la machine décrite dans [01-ma-configuration.md](01-ma-configuration.md).
Ce qui suit indique, configuration par configuration, ce qui reste valable et ce qu'il faut sûrement changer.
Les cas marqués *non testé* sont des pistes, pas des recettes vérifiées.

## Ce qui est indépendant de la carte

- les **workflows** (`workflows\*.json`) : ce sont des graphes ComfyUI standard, sans nœud tiers ;
- `scripts\telecharger_modeles.py` (`--comfyui <dossier ComfyUI>`), `scripts\executer_workflow.py`, `tests\captures.py` :
  Python, bibliothèque standard ;
- la documentation des workflows et des réglages.

Seuls les scripts 2 et 3 et les chemins de `scripts\commun.ps1` sont propres à « AMD AI Bundle + RDNA 4 ».

## Autre carte AMD RDNA 4

| Carte | Architecture | Ce qu'il faut faire |
|---|---|---|
| RX 9070 / 9070 XT | `gfx1201` | rien, c'est la configuration testée (9070 XT : *non testé*, même puce) |
| RX 9060 XT | `gfx1200` | `scripts\installer.ps1 -Gfx gfx1200` — *non testé* |
| Ryzen AI Max (« Strix Halo ») | `gfx1151` | `-Gfx gfx1151` — *non testé* ; mémoire partagée : beaucoup de « VRAM » mais plus lent |

## Carte AMD plus ancienne (RDNA 3, RX 7000…)

Les wheels utilisées ici n'existent que pour `gfx1151`, `gfx1200` et `gfx1201`. Pour une RX 7900 (`gfx1100`), une RX 7600
(`gfx1102`)…, chercher dans la documentation ROCm pour Windows d'AMD
(https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/) les wheels PyTorch correspondant à l'architecture, puis
adapter les tableaux du script 2 (noms de fichiers, URL, SHA256). Le reste (lanceur, modèles, workflows) ne change pas.
*Non testé.* L'option `-Gfx` du script n'accepte volontairement que les trois architectures connues.

## Pas d'iGPU (processeur sans graphiques intégrés, ou iGPU désactivé dans le BIOS)

ROCm ne voit qu'une carte, en device 0. `scripts\3-configurer-lanceur.ps1` le détecte et écrit `--cuda-device 0` (ou
rien à faire : c'est le défaut de ComfyUI).

## Carte NVIDIA

**Ne pas lancer** les scripts 2 et 3 (PyTorch ROCm inutile). À la place :

1. installer **ComfyUI Portable** pour NVIDIA (https://github.com/comfyanonymous/ComfyUI/releases) ou ComfyUI Desktop
   (https://www.comfy.org/download) — PyTorch CUDA inclus ;
2. télécharger les modèles avec le Python de ComfyUI :
   `python scripts\telecharger_modeles.py --comfyui <dossier ComfyUI> sdxl controlnet` ;
3. glisser les workflows dans ComfyUI.

Avec une **version récente de ComfyUI** (postérieure à 0.3.68), le workflow 5 peut utiliser directement le fichier officiel
`qwen_image_edit_2511_fp8mixed.safetensors` : télécharger ce fichier (lien dans [references.md](references.md)) au lieu
du groupe `qwen` du script, puis choisir ce fichier dans le nœud *Modèle Qwen-Image-Edit-2511*.

## ComfyUI installé autrement (Desktop, Portable, git clone)

Définir la variable d'environnement `COMFYUI_RACINE` vers le dossier qui contient `ComfyUI\` (le dépôt), `venv\` et
`Launch_ComfyUI.bat`, ou modifier les chemins en tête de `scripts\commun.ps1`. Si la structure diffère trop, utiliser
directement les scripts Python (`telecharger_modeles.py --comfyui …`) et copier les workflows à la main.
Le PyTorch doit être compilé pour **Python 3.12** pour les wheels AMD utilisées ici.

## Moins de mémoire

| Ressource | Conséquence | Adaptation |
|---|---|---|
| 12 Go de VRAM | SDXL base + refiner ne tiennent plus ensemble | désactiver le refiner (workflow 1) ; ComfyUI décharge alors moins |
| 8 Go de VRAM | SDXL lent | lancer ComfyUI avec `--lowvram` (à ajouter dans le lanceur) ; images 1024 sans upscale |
| < 32 Go de RAM | Qwen-Image-Edit (≈ 30 Go de modèles) très lent ou impossible | version GGUF quantifiée (ex. Q4_K_M ≈ 13 Go), mais elle demande le nœud tiers **ComfyUI-GGUF** — *non testé* |
| Disque | ≈ 16 Go (SDXL + ControlNet), ≈ 47 Go avec Qwen, + 20,5 Go temporaires | ne télécharger que les groupes utiles |

## Mettre à jour ComfyUI

Une version plus récente apporte de nouveaux modèles et règle le problème du format Qwen `fp8mixed`, mais :
- l'AMD Install Manager peut **réinstaller son PyTorch** (sans kernels pour la carte) et son lanceur : relancer
  `scripts\installer.ps1` après coup ;
- les workflows d'ici n'utilisent que des nœuds intégrés et devraient rester compatibles — à vérifier avec
  `scripts\tester-installation.ps1`.
