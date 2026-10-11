"""Liste les GPU vus par PyTorch (ROCm) et indique lequel donner à ComfyUI (--cuda-device).

À lancer avec le Python du venv de ComfyUI. Ne fait aucun calcul sur les GPU : lit seulement leurs propriétés
(un calcul sur l'iGPU Ryzen, non pris en charge, fait planter le processus).

Usage : python detecter_gpu.py [--gfx gfx1201] [--index-seul]
  --gfx        architecture voulue (défaut : la carte qui a le plus de mémoire)
  --index-seul n'affiche que l'index retenu (pour les scripts)
"""
import argparse, sys

p = argparse.ArgumentParser()
p.add_argument("--gfx")
p.add_argument("--index-seul", action="store_true")
a = p.parse_args()

try:
    import torch
except ImportError:
    sys.exit("PyTorch introuvable : lancer ce script avec le Python du venv de ComfyUI.")

if not torch.cuda.is_available():
    sys.exit(f"PyTorch {torch.__version__} ne voit aucun GPU (HIP {torch.version.hip}).")

gpus = []
for i in range(torch.cuda.device_count()):
    pr = torch.cuda.get_device_properties(i)
    gpus.append((i, pr.name, getattr(pr, "gcnArchName", "?").split(":")[0], pr.total_memory))

if a.gfx:
    choix = [g for g in gpus if g[2] == a.gfx]
    if not choix:
        sys.exit(f"Aucun GPU {a.gfx} parmi : " + ", ".join(f"{g[0]}={g[2]}" for g in gpus))
    retenu = choix[0]
else:
    retenu = max(gpus, key=lambda g: g[3])

if a.index_seul:
    print(retenu[0])
    sys.exit(0)

print(f"PyTorch {torch.__version__} (HIP {torch.version.hip})")
for i, nom, arch, mem in gpus:
    print(f"  device {i} : {nom:<32} {arch:<9} {mem / 2**30:5.1f} Go{'   <- retenu' if i == retenu[0] else ''}")
print(f"\nComfyUI doit être lancé avec : main.py --cuda-device {retenu[0]}")
