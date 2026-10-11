"""Convertit un modèle au nouveau format de quantification ComfyUI (« fp8mixed » : _quantization_metadata, weight_scale,
input_scale, comfy_quant) vers l'ancien format « scaled_fp8 » (scale_weight + marqueur scaled_fp8) lu par ComfyUI 0.3.68.
Copie brute des octets, tenseur par tenseur : rien n'est recalculé, rien n'est chargé en entier en mémoire.
Le marqueur __index_timestep_zero__ (propre à Qwen-Image-Edit-2511) est retiré : ComfyUI 0.3.68 ne le gère pas.
Usage : py qwen_fp8mixed_vers_scaled.py <source.safetensors> <destination.safetensors>"""
import json, os, struct, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, "rb") as f:
    n = struct.unpack("<Q", f.read(8))[0]
    h = json.loads(f.read(n))
debut_src = 8 + n
h.pop("__metadata__", None)

sortie, plan, pos = {}, [], 0
for k, v in sorted(h.items(), key=lambda kv: kv[1]["data_offsets"][0]):
    if k == "__index_timestep_zero__" or k.endswith((".input_scale", ".comfy_quant")):
        continue
    nk = k[: -len(".weight_scale")] + ".scale_weight" if k.endswith(".weight_scale") else k
    a, b = v["data_offsets"]
    sortie[nk] = {"dtype": v["dtype"], "shape": v["shape"], "data_offsets": [pos, pos + (b - a)]}
    plan.append((a, b))
    pos += b - a
sortie["scaled_fp8"] = {"dtype": "F8_E4M3", "shape": [2], "data_offsets": [pos, pos + 2]}   # marqueur de l'ancien format
entete = json.dumps(sortie, separators=(",", ":")).encode()
entete += b" " * (-len(entete) % 8)

with open(src, "rb") as fs, open(dst + ".part", "wb") as fd:
    fd.write(struct.pack("<Q", len(entete)) + entete)
    for a, b in plan:
        fs.seek(debut_src + a)
        reste = b - a
        while reste:
            bloc = fs.read(min(reste, 1 << 26))
            fd.write(bloc)
            reste -= len(bloc)
    fd.write(b"\x00\x00")
os.replace(dst + ".part", dst)
print(f"{len(sortie)} tenseurs, {os.path.getsize(dst) / 1e9:.2f} Go → {dst}")
