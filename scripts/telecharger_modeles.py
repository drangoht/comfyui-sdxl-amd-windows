"""Télécharge les modèles utilisés par les workflows depuis leurs sources officielles et vérifie leur SHA256.

À lancer avec le Python du venv de ComfyUI (scripts\\4-telecharger-modeles.ps1 le fait). Bibliothèque standard + PyYAML
(fourni avec ComfyUI). Un téléchargement interrompu (.part) reprend là où il s'était arrêté.

Usage :
    python telecharger_modeles.py --comfyui <dossier ComfyUI> [groupes...] [--verifier [--rapide]]

Groupes (défaut : sdxl) :
    sdxl        SDXL base + refiner + RealESRGAN x2          ≈ 13 Go   workflows 1, 2, 3
    controlnet  ControlNet Union ProMax pour SDXL             ≈ 2,5 Go  workflow 4
    qwen        Qwen-Image-Edit-2511 (+ conversion, cf. doc)  ≈ 31 Go   workflow 5  (+ 20,5 Go temporaires)
    tout        les trois

--verifier          ne télécharge rien : contrôle la présence et le SHA256 des fichiers
--rapide            avec --verifier : contrôle la taille seulement (instantané)
--dossier-modeles   dossier « models » à utiliser à la place de <ComfyUI>\\models (mêmes sous-dossiers que ComfyUI)

Un modèle déjà présent dans un dossier déclaré par <ComfyUI>\\extra_model_paths.yaml (ex. modèles partagés avec A1111)
est vérifié sur place et n'est pas retéléchargé. Les nouveaux téléchargements vont dans <ComfyUI>\\models.
"""
import argparse, hashlib, os, subprocess, sys, time, urllib.request

HF = "https://huggingface.co"
# (groupe, sous-dossier ComfyUI, nom du fichier, URL, taille en octets, SHA256)
MODELES = [
    ("sdxl", "checkpoints", "sd_xl_base_1.0.safetensors",
     f"{HF}/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors",
     6938078334, "31e35c80fc4829d14f90153f4c74cd59c90b779f6afe05a74cd6120b893f7e5b"),
    ("sdxl", "checkpoints", "sd_xl_refiner_1.0.safetensors",
     f"{HF}/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors",
     6075981930, "7440042bbdc8a24813002c09b6b69b64dc90fded4472613437b7f55f9b7d9c5f"),
    ("sdxl", "upscale_models", "RealESRGAN_x2plus.pth",
     "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
     67061725, "49fafd45f8fd7aa8d31ab2a22d14d91b536c34494a5cfe31eb5d89c2fa266abb"),
    ("controlnet", "controlnet", "controlnet-union-sdxl-promax.safetensors",
     f"{HF}/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors",
     2513342408, "9fae2e50cb431bfcbe05822b59ec2228df545ef27f711dea8949e9f4ed9f7cdc"),
    ("qwen", "vae", "qwen_image_vae.safetensors",
     f"{HF}/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors",
     253806246, "a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f"),
    ("qwen", "text_encoders", "qwen_2.5_vl_7b_fp8_scaled.safetensors",
     f"{HF}/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
     9384670680, "cb5636d852a0ea6a9075ab1bef496c0db7aef13c02350571e388aea959c5c0b4"),
    ("qwen", "loras", "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
     f"{HF}/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
     849608296, "22226e8d05d354bb356627d428809f5afd7819399b077238a2b70a82883a904f"),
]
# Qwen-Image-Edit-2511 : le fichier publié (format « fp8mixed ») n'est pas lisible par ComfyUI 0.3.68.
# On le télécharge puis on le convertit à l'ancien format « scaled_fp8 » (copie d'octets, résultat identique au bit près).
QWEN_SOURCE = ("diffusion_models", "qwen_image_edit_2511_fp8mixed.safetensors",
               f"{HF}/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors",
               20533762817, "c9fdc158e46d3b61ef75f21ae866ca2fe808bf4a53643120d1c1e87c19280a4e")
QWEN_CONVERTI = ("diffusion_models", "qwen_image_edit_2511_scaled_fp8.safetensors",
                 20533426222, "21f748fc3a004d47fa100a85c04a70a3bc6ab375de0999bc9293724d6f6807ae")

EXTRA = {}  # catégorie -> dossiers supplémentaires (extra_model_paths.yaml)


def go(n):
    return f"{n / 1e9:.2f} Go"


def sha256(chemin):
    h = hashlib.sha256()
    with open(chemin, "rb") as f:
        for bloc in iter(lambda: f.read(1 << 24), b""):
            h.update(bloc)
    return h.hexdigest()


def dossiers_extra(comfyui):
    """Dossiers supplémentaires par catégorie, lus dans extra_model_paths.yaml (même logique que ComfyUI)."""
    chemin = os.path.join(comfyui, "extra_model_paths.yaml")
    if not os.path.exists(chemin):
        return {}
    try:
        import yaml  # PyYAML, fourni avec ComfyUI
    except ImportError:
        print("(PyYAML absent : extra_model_paths.yaml ignoré ; lancer ce script avec le Python du venv de ComfyUI)")
        return {}
    with open(chemin, encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}
    extra = {}
    for section in config.values():
        if not isinstance(section, dict):
            continue
        base = os.path.expandvars(os.path.expanduser(section.get("base_path", "")))
        if base and not os.path.isabs(base):
            base = os.path.join(comfyui, base)
        for cle, valeur in section.items():
            if cle in ("base_path", "is_default") or not isinstance(valeur, str):
                continue
            cle = {"unet": "diffusion_models", "clip": "text_encoders"}.get(cle, cle)
            for ligne in valeur.splitlines():
                if ligne.strip():
                    extra.setdefault(cle, []).append(os.path.normpath(os.path.join(base, ligne.strip())))
    return extra


def trouver(dossier_modeles, sous_dossier, nom):
    """Chemin existant du modèle (models\\ puis extra_model_paths.yaml), sinon chemin de destination dans models\\."""
    for d in [os.path.join(dossier_modeles, sous_dossier)] + EXTRA.get(sous_dossier, []):
        if os.path.exists(os.path.join(d, nom)):
            return os.path.join(d, nom)
    return os.path.join(dossier_modeles, sous_dossier, nom)


def telecharger(url, dest, taille):
    part = dest + ".part"
    deja = os.path.getsize(part) if os.path.exists(part) else 0
    entetes = {"User-Agent": "telecharger_modeles.py"}
    if deja:
        entetes["Range"] = f"bytes={deja}-"
        print(f"    reprise à {go(deja)}")
    with urllib.request.urlopen(urllib.request.Request(url, headers=entetes)) as r:
        if r.status != 206:
            deja = 0
        with open(part, "ab" if deja else "wb") as f:
            t0, recu, affiche = time.time(), deja, 0
            while bloc := r.read(1 << 20):
                f.write(bloc)
                recu += len(bloc)
                if time.time() - affiche > 2:
                    vitesse = (recu - deja) / max(time.time() - t0, 0.1) / 1e6
                    print(f"\r    {go(recu)} / {go(taille)}  ({vitesse:.0f} Mo/s)   ", end="", flush=True)
                    affiche = time.time()
    print()
    os.replace(part, dest)


def traiter(dossier_modeles, sous_dossier, nom, url, taille, sha, verifier, rapide=False):
    dest = trouver(dossier_modeles, sous_dossier, nom)
    print(f"- {nom} ({go(taille)})  {os.path.dirname(dest)}")
    present = os.path.exists(dest) and os.path.getsize(dest) == taille
    if not present:
        if verifier or url is None:
            print("    ABSENT" if not os.path.exists(dest) else "    TAILLE INCORRECTE")
            return False
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        print(f"    téléchargement depuis {url}")
        telecharger(url, dest, taille)
    if rapide:
        print("    présent")
        return True
    print("    vérification SHA256…", end=" ", flush=True)
    if sha256(dest) != sha:
        print("FAUX : fichier corrompu ou modifié à la source. Le supprimer et relancer.")
        return False
    print("OK")
    return True


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--comfyui", required=True, help="dossier ComfyUI qui contient main.py")
    p.add_argument("--dossier-modeles")
    p.add_argument("--verifier", action="store_true")
    p.add_argument("--rapide", action="store_true")
    p.add_argument("--garder-original-qwen", action="store_true", help="ne pas supprimer le fp8mixed (20,5 Go) après conversion")
    p.add_argument("groupes", nargs="*", default=["sdxl"])
    a = p.parse_args()
    connus = {"sdxl", "controlnet", "qwen"}
    groupes = connus if "tout" in a.groupes else set(a.groupes)
    if groupes - connus:
        sys.exit(f"Groupe inconnu : {', '.join(groupes - connus)}")
    modeles = a.dossier_modeles or os.path.join(a.comfyui, "models")
    if not os.path.isdir(modeles):
        sys.exit(f"Dossier introuvable : {modeles}")
    EXTRA.update(dossiers_extra(a.comfyui))
    rapide = a.verifier and a.rapide

    a_telecharger = sum(t for g, sd, n, u, t, s in MODELES if g in groupes and not os.path.exists(trouver(modeles, sd, n)))
    if "qwen" in groupes and not os.path.exists(trouver(modeles, QWEN_CONVERTI[0], QWEN_CONVERTI[1])):
        a_telecharger += QWEN_SOURCE[3]
    if not a.verifier and a_telecharger:
        print(f"À télécharger : environ {go(a_telecharger)} vers {modeles}\n")

    ok = True
    for g, sd, n, u, t, s in MODELES:
        if g in groupes:
            ok &= traiter(modeles, sd, n, u, t, s, a.verifier, rapide)

    if "qwen" in groupes:
        sd, n, t, s = QWEN_CONVERTI
        converti = trouver(modeles, sd, n)
        if os.path.exists(converti) or a.verifier:
            ok &= traiter(modeles, sd, n, None, t, s, True, rapide)
        else:
            ssd, sn, su, st, ss = QWEN_SOURCE
            source = trouver(modeles, ssd, sn)
            if traiter(modeles, ssd, sn, su, st, ss, False):
                print("    conversion fp8mixed -> scaled_fp8 (quelques minutes)…", flush=True)
                script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qwen_fp8mixed_vers_scaled.py")
                subprocess.run([sys.executable, script, source, converti], check=True)
                conv_ok = traiter(modeles, sd, n, None, t, s, True)
                ok &= conv_ok
                if conv_ok and not a.garder_original_qwen:
                    os.remove(source)
                    print(f"    original fp8mixed supprimé ({go(st)} libérés)")
            else:
                ok = False

    print("\nTout est en place." if ok else "\nDes fichiers manquent ou sont invalides (voir ci-dessus).")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
