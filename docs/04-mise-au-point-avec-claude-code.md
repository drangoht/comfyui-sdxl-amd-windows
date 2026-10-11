# 4. Comment l'installation a été rendue fonctionnelle (avec Claude Code)

Cette installation a été mise au point en octobre 2026 avec **[Claude Code](https://claude.com/claude-code)**, l'agent de
programmation d'Anthropic, utilisé dans l'application de bureau Claude (onglet *Code*) sous Windows. Le propriétaire de la
machine décrivait ce qu'il voulait ; Claude Code lisait les journaux, inspectait les installations, lançait les commandes,
testait chaque workflow par l'API de ComfyUI et rendait compte, en demandant confirmation avant chaque téléchargement
(nom, source, taille) et sans supprimer de fichiers de l'utilisateur.

Ce document retrace les étapes, y compris les impasses : c'est souvent là qu'on apprend le plus.

## Point de départ (3 octobre 2026)

- Une installation **AUTOMATIC1111** (Stable Diffusion WebUI) existante tournait… **sur le processeur** : son PyTorch était
  la version CUDA (NVIDIA), inutilisable avec une carte AMD.
- L'**AMD AI Bundle** avait installé un ComfyUI 0.3.68, qui plantait dès la première image.

## Étape 1 — Pourquoi ComfyUI plante : les kernels manquants

Message au premier calcul : `hipErrorInvalidImage`. HIP (l'équivalent AMD de CUDA) ne trouvait pas de code compilé pour
la carte. Claude Code a comparé :

- le PyTorch du venv de ComfyUI : `2.12.0+rocm7.14.0`, wheels « génériques » `rocm-rel-7.14_a` — **aucun kernel `gfx1201`** ;
- le composant **« PyTorch »** du même AI Bundle, installé à part dans le Python 3.12 du système :
  `2.13.0+rocm10.0.0`, avec des paquets par architecture (`amd_torch_device_gfx1201`, `rocm_sdk_device_gfx1201`…).

Les deux jeux de wheels étaient déjà sur le disque (`C:\Program Files\AMD\AMDInstallManager\DownloadedFiles`) avec leurs
SHA256 dans le manifeste `AIBundle.json`. Solution : installer le second dans le venv de ComfyUI, après avoir sauvegardé
la liste des paquets (`venv-freeze-avant-rocm10.txt`). Au passage, `torchaudio` manquait dans l'installation d'origine :
une faute de frappe dans la ligne de commande du manifeste (`+Brocm7.14.0` au lieu de `+rocm7.14.0`).

→ automatisé par `scripts\2-installer-pytorch-rocm10.ps1`.

## Étape 2 — Deux GPU au lieu d'un

Même avec le bon PyTorch, la génération plantait. `torch.cuda.device_count()` renvoyait **2** : le Ryzen 9800X3D a des
graphiques intégrés (`gfx1036`), exposés en **device 0** et non pris en charge par ROCm ; la RX 9070 est le device 1.
ComfyUI prend le device 0 par défaut. Correction : `--cuda-device 1` dans `Launch_ComfyUI.bat` (copie de l'original
gardée).

→ automatisé par `scripts\3-configurer-lanceur.ps1`, qui détecte le bon numéro sans calculer sur l'iGPU.

Première image SD 1.5 : **12 it/s**, 2,6 s par image 512×512. SDXL 1024 : ≈ 15 s.

## Étape 3 — Les modèles et leur emplacement

Plutôt que de dupliquer les modèles, ComfyUI lit ceux de l'installation A1111 grâce à `extra_model_paths.yaml`.
SDXL base et refiner ont été téléchargés depuis les dépôts officiels de Stability AI, **SHA256 vérifiés**.

→ `scripts\telecharger_modeles.py` reprend cette logique (sources officielles, SHA256, reprise, prise en compte
d'`extra_model_paths.yaml`).

## Étape 4 — Des workflows prêts à l'emploi… et testés

Chaque workflow a été écrit, puis **exécuté par l'API de ComfyUI** (`POST /prompt`, lecture de `/history`) sur une vraie
image, et ses valeurs par défaut calibrées sur le résultat. Exemples :

- **image → image** : à denoise 0,55, le rendu restait « peint » ; à 0,7, vraie aquarelle avec pose et cadrage gardés →
  défaut 0,65 ;
- **retouche d'une zone** : masque agrandi de 16 px et flouté, `DifferentialDiffusion`, puis recollage dans l'original
  pour que le reste de l'image ne bouge pas d'un pixel ;
- **ControlNet** : ControlNet Union ProMax + détecteur **Canny intégré** à ComfyUI, plutôt qu'un paquet de nœuds tiers
  (choix du propriétaire : pas de code tiers quand une solution intégrée existe).

→ `scripts\executer_workflow.py` est la version propre de ces outils de test.

## Étape 5 — L'upscale : de 130 s à 52 s par image

Le premier workflow texte → image (1024 → upscale → 2048) prenait **120 à 137 s**. Claude Code a chronométré chaque nœud
(messages websocket de ComfyUI) :

| Étape | Avant | Après |
|---|---|---|
| Upscale | RealESRGAN **x4** puis réduction ×0,5 : 16–56 s | RealESRGAN **x2** direct : ≈ 4,5 s |
| Encodage VAE 2048 | tuiles de 1024 : 14 s | tuiles de **512** : 3–4 s |
| Affinage | 10 pas : 27 s | **6 pas** (visuellement équivalent) : ≈ 17 s |
| Décodage VAE 2048 | tuiles de 1024 : 19 s | tuiles de **512** : 7,4 s |

Impasses notées : `--use-pytorch-cross-attention` plante sous ROCm Windows (`hipErrorInvalidValue` sur l'attention
masquée de CLIP) ; `--use-split-cross-attention` est 3× plus lent ; un VAE non tuilé en 2048 sature les 16 Go et force le
déchargement des modèles ; `denoise 0,3` n'économise pas de pas (le KSampler les exécute tous).

## Étape 6 — Qwen-Image-Edit-2511 sur un ComfyUI trop ancien

Le modèle officiel pour ComfyUI (`qwen_image_edit_2511_fp8mixed`) faisait planter ComfyUI 0.3.68 : *« Promotion for Float8
Types is not supported »*, même sans LoRA. Claude Code a lu l'en-tête du fichier `.safetensors` : nouvelle quantification
(`weight_scale`, `input_scale`, `comfy_quant`, métadonnées `_quantization_metadata`), inconnue de la 0.3.68 qui attend
l'ancien format `scaled_fp8` (`scale_weight` + marqueur `scaled_fp8`).

Plutôt que de mettre à jour ComfyUI (et risquer de perdre les correctifs ROCm), il a écrit un convertisseur qui **recopie
les tenseurs octet pour octet** sous les anciens noms, sans rien recalculer ni charger en mémoire — résultat : 20,5 Go
convertis en quelques minutes, et le modèle fonctionne. Le marqueur `__index_timestep_zero__`, propre à la 2511, est retiré
(non géré par la 0.3.68).

→ `scripts\qwen_fp8mixed_vers_scaled.py`, appelé par le téléchargeur. Mesures : changement de décor ≈ 4 min à froid,
composition de 2 images ≈ 6,5 min.

## Étape 7 — Un piège propre à l'application Claude Desktop

L'application de bureau Claude est empaquetée en **MSIX** : ce qu'un processus lancé depuis l'application écrit dans
`%APPDATA%` / `%LOCALAPPDATA%` (et dans `HKCU`) est **redirigé** vers un dossier privé du paquet, invisible du reste de
Windows. Pour que ComfyUI survive à l'application et que les réglages soient réellement écrits, Claude Code lançait les
processus durables via WMI (`Invoke-CimMethod Win32_Process -MethodName Create`), hors du conteneur. Ce point ne concerne
pas l'utilisateur qui lance les scripts du dépôt depuis un PowerShell normal.

## Étape 8 — Ce dépôt (11 octobre 2026)

À la demande du propriétaire, Claude Code a rassemblé le tout dans ce dépôt public :

- les correctifs manuels sont devenus des **scripts idempotents** (relançables sans risque), avec les URL et SHA256
  officiels d'AMD, de Hugging Face et de GitHub ;
- les chemins et données personnels ont été retirés (workflows pointant vers des images de départ générées par SDXL) ;
- les **images d'exemple** ont été produites par les workflows du dépôt, par l'API, avec des graines fixes ;
- les **captures d'écran** viennent de `tests\captures.py`, qui pilote Chrome en mode headless par le protocole DevTools
  (client websocket écrit en bibliothèque standard) et lance chaque workflow comme le bouton *Exécuter* ;
- **`tests\tester-tout.ps1`** rejoue l'installation entière sur une copie remise dans l'état d'usine d'AMD — ce qui a
  confirmé que le problème d'origine (`hipErrorInvalidImage`) est bien reproduit, puis corrigé par `installer.ps1` —
  et exécute les 5 workflows.

## Ce qu'il faut retenir

1. Sous Windows, PyTorch pour AMD dépend **de l'architecture exacte** du GPU (`gfx1201`…) : vérifier que les wheels la
   contiennent.
2. Un **iGPU** Ryzen peut être vu par ROCm : toujours choisir explicitement le device.
3. Vérifier chaque téléchargement par **SHA256**, et tester chaque workflow **par l'API** avant de le considérer prêt.
4. Une réparation ou mise à jour par l'AMD Install Manager peut écraser ces correctifs : relancer `scripts\installer.ps1`.
