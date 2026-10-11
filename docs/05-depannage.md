# 5. Dépannage

Premier réflexe : `powershell -ExecutionPolicy Bypass -File scripts\1-verifier-installation.ps1` (ne modifie rien) et
lire la **fenêtre console** de ComfyUI, où s'affichent les erreurs.

| Symptôme | Cause probable | Solution |
|---|---|---|
| `hipErrorInvalidImage` au premier calcul | PyTorch livré par l'AI Bundle (ROCm 7.14), sans kernels pour la carte | `scripts\2-installer-pytorch-rocm10.ps1` |
| ComfyUI plante ou se ferme dès la génération, la carte n'est plus vue | ComfyUI tourne sur l'iGPU (device 0) | `scripts\3-configurer-lanceur.ps1` |
| Tout remarchait puis plus rien après une mise à jour du pilote ou de l'AI Bundle | l'AMD Install Manager a réinstallé ou « réparé » ComfyUI et écrasé les correctifs | relancer `scripts\installer.ps1` |
| `hipErrorInvalidValue` au chargement de CLIP | option `--use-pytorch-cross-attention` ajoutée au lanceur | la retirer (incompatible avec ROCm sous Windows) |
| « Promotion for Float8 Types is not supported » (workflow 5) | fichier Qwen `fp8mixed` d'origine utilisé avec ComfyUI 0.3.68 | utiliser `qwen_image_edit_2511_scaled_fp8` (`4-telecharger-modeles.ps1 -Groupes qwen`) |
| Nœud rouge, « value not in list » à l'ouverture d'un workflow | modèle absent | `scripts\4-telecharger-modeles.ps1 -Verifier`, puis touche **R** dans ComfyUI pour rafraîchir les listes |
| Page inaccessible sur http://127.0.0.1:8188 | ComfyUI non lancé ou encore en démarrage | `scripts\lancer-comfyui.ps1` ; le 1er démarrage prend ~30 s |
| Génération très lente, « loaded partially » dans la console | mémoire de la carte saturée | fermer jeux, navigateurs chargés, autres applis GPU ; réduire la taille ; garder les VAE en tuiles |
| Lent alors que ça allait vite avant (ex. affinage 8 s/pas au lieu de 2,6) | état passager du GPU ou appli concurrente | redémarrer ComfyUI ; regarder ce qui utilise le GPU (Gestionnaire des tâches) |
| PC inutilisable pendant une série d'images | la carte et la RAM sont saturées | `lancer-comfyui.ps1 -PrioriteBasse` ; désactiver le refiner pour des essais |
| Image floue, doublons, membres en trop (SDXL) | taille hors des formats SDXL (~1 Mpx), CFG trop bas | 1024×1024, 1216×832… ; CFG 6–8 |
| Les scripts refusent de se lancer (« l'exécution de scripts est désactivée ») | stratégie d'exécution PowerShell | `powershell -ExecutionPolicy Bypass -File …` ; dépôt téléchargé en .zip : `Get-ChildItem -Recurse \| Unblock-File` |
| Accents illisibles dans la console | ancienne page de code de la console | sans conséquence ; `chcp 65001` avant de lancer les scripts |
| Téléchargement interrompu | coupure réseau | relancer `4-telecharger-modeles.ps1` : il reprend au fichier `.part` |
| « SHA256 FAUX » | fichier corrompu ou modifié à la source | supprimer le fichier indiqué et relancer ; si ça persiste, la source a changé : vérifier sur Hugging Face |

## Revenir en arrière

**PyTorch** : la liste des paquets d'avant la correction est dans `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\venv-freeze-avant-rocm10.txt`.
Les wheels d'origine (ROCm 7.14) sont dans `C:\Program Files\AMD\AMDInstallManager\DownloadedFiles`. Pour revenir à
l'état d'origine (inutile sur RX 9070, puisqu'il ne fonctionne pas) : désinstaller `amd-torch-device-gfx1201`,
`amd-torchvision-device-gfx1201`, `rocm-sdk-device-gfx1201`, puis installer les 7 fichiers `*7.14*` /
`torch-2.12.0+rocm7.14.0…` avec `python -m pip install` (c'est ce que fait l'étape 2 de `tests\tester-tout.ps1` sur sa copie).
Plus simple : faire réparer ComfyUI par l'AMD Install Manager.

**Lanceur** : remettre `Launch_ComfyUI.bat.bak-origine` à la place de `Launch_ComfyUI.bat`.

**Workflows / modèles** : supprimer les fichiers dans `ComfyUI\user\default\workflows\` et `ComfyUI\models\`.

## Désinstaller

Désinstaller ComfyUI depuis l'AMD Install Manager (ou `Uninstall_ComfyUI.bat` dans son dossier), puis supprimer le
dossier `%LOCALAPPDATA%\AMD\AI_Bundle\ComfyUI\` s'il reste (modèles compris, s'ils étaient dans `ComfyUI\models\`).
Les wheels mises en cache par le script 2 (si elles ont été téléchargées) sont dans
`%LOCALAPPDATA%\comfyui-sdxl-amd-windows\wheels\`.
