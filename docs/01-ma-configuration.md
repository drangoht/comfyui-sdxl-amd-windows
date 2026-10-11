# 1. La configuration de référence

Tout ce dépôt a été mis au point et testé sur **une seule machine**. Ce qui suit décrit cette machine et ce qui, dans
l'installation, en dépend. Si votre configuration diffère, lisez aussi [06-autre-configuration.md](06-autre-configuration.md).

## Matériel

| Élément | Valeur | Pourquoi c'est important |
|---|---|---|
| Carte graphique | **AMD Radeon RX 9070**, 16 Go de VRAM | Architecture **RDNA 4**, nom ROCm **`gfx1201`**. PyTorch doit contenir des kernels compilés pour cette architecture précise : c'est ce qui manquait dans le PyTorch livré avec ComfyUI. |
| Processeur | AMD Ryzen 7 9800X3D | Il a des **graphiques intégrés** (`gfx1036`). ROCm les voit comme un 2ᵉ GPU, en **device 0**, non pris en charge : ComfyUI plante s'il les utilise. D'où `--cuda-device 1`. |
| Mémoire vive | 32 Go | SDXL (base + refiner ≈ 13 Go) tient en VRAM ; Qwen-Image-Edit (20 Go + 9 Go d'encodeur) **déborde en RAM** : 32 Go est un minimum pour le workflow 5. |
| Disque | SSD NVMe | Chargement des modèles (≈ 30 Go pour tout) ; le premier lancement de chaque workflow est plus lent. |

## Logiciels

| Élément | Version | Remarque |
|---|---|---|
| Windows | 11 Pro (build 26300) | Fonctionne a priori aussi sous Windows 10 64 bits (exigence de l'AMD Install Manager). |
| Pilote AMD | Adrenalin 32.0.31041.1004 | ROCm sous Windows passe par le pilote graphique : un pilote récent est nécessaire. |
| AMD AI Bundle / AMD Install Manager | composant **ComfyUI 0.3.68** (12/09/2026) | Installe dans `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\` : Python 3.12.10 embarqué, Git, un venv et le dépôt ComfyUI. |
| Python (embarqué) | 3.12.10 | Les wheels PyTorch d'AMD sont en `cp312` : **Python 3.12 obligatoire** pour ce venv. |
| PyTorch | **2.13.0+rocm10.0.0** | Remplace le `2.12.0+rocm7.14.0` livré (sans kernels `gfx1201`). Wheels du composant « PyTorch » de l'AI Bundle. |
| torchvision / torchaudio | 0.28.0 / 2.11.0.2 (+rocm10.0.0) | |
| ROCm SDK (wheels Python) | 10.0.0 : `rocm`, `rocm-sdk-core`, `rocm-sdk-libraries`, `rocm-sdk-devel`, `rocm-sdk-device-gfx1201` | ROCm sous Windows est livré sous forme de paquets Python, rien à installer à part. |
| Interface ComfyUI | `comfyui_frontend_package` 1.28.8 | Les captures d'écran viennent de cette version (interface en français). |

## Ce qui, dans le dépôt, dépend de cette configuration

| Endroit | Valeur liée à la machine | À changer si… |
|---|---|---|
| `scripts\commun.ps1` | chemin `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI` | ComfyUI n'a pas été installé par l'AMD AI Bundle (ou variable `COMFYUI_RACINE`) |
| `scripts\2-installer-pytorch-rocm10.ps1` | wheels `gfx1201` / `gfx1200` / `gfx1151`, Python 3.12 | autre GPU AMD, ou NVIDIA (ne pas lancer ce script) |
| `scripts\3-configurer-lanceur.ps1` | `--cuda-device` détecté (1 ici) | rien : la détection est automatique (paramètre `-Index` pour forcer) |
| Workflows 1 à 4 | 1024 px + upscale x2, VAE en tuiles de 512 | moins de 12 Go de VRAM : désactiver le refiner et l'upscale |
| Workflow 5 | Qwen fp8 (20 Go) + LoRA 4 pas | moins de 16 Go de VRAM ou 32 Go de RAM : version GGUF (nœud tiers), cf. doc 06 |
| `telecharger_modeles.py` | conversion `fp8mixed` → `scaled_fp8` | ComfyUI plus récent que 0.3.68 : inutile (utiliser le fichier officiel) |

## Performances mesurées (RX 9070, réglages par défaut des workflows)

| Opération | Temps |
|---|---|
| SD 1.5, 512×512, 20 pas | ≈ 12 it/s, 2,6 s/image |
| SDXL 1024×1024, 25 pas (base + refiner) | ≈ 16 s (≈ 0,5 s/pas) |
| Workflow 1 complet (1024 → upscale x2 → affinage → 2048×2048) | **≈ 52 s** (≈ 64 s pour la 1ʳᵉ image de la session) |
| Workflow 2 image → image (30 pas, 1 Mpx) | ≈ 19–23 s |
| Workflow 3 retouche d'une zone | ≈ 18–19 s |
| Workflow 4 ControlNet contours | ≈ 24–25 s |
| Workflow 5 Qwen-Image-Edit, 4 pas Lightning, 1 image | ≈ 2,5 min (≈ 4 min à froid) ; 2 images ≈ 6,5 min |

Pendant une génération, la carte et une bonne partie de la RAM sont occupées : la machine est peu réactive.
`scripts\lancer-comfyui.ps1 -PrioriteBasse` atténue un peu l'effet.
