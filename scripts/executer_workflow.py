"""Exécute un workflow ComfyUI (fichier .json enregistré depuis l'interface) par l'API, sans ouvrir le navigateur.

Sert à tester l'installation et à produire des images en série. Bibliothèque standard uniquement.

Exemples :
    python executer_workflow.py "..\\workflows\\1 - SDXL texte vers image.json"
    python executer_workflow.py "..\\workflows\\1 - SDXL texte vers image.json" --prompt "a lighthouse at dawn" --seed 42
    python executer_workflow.py "..\\workflows\\2 - SDXL image vers image.json" --image photo.png --regler "Transformation:denoise=0.7"
    python executer_workflow.py "..\\workflows\\5 - Qwen édition par instruction.json" --image a.png --image b.png --prompt "..."

Options :
    --prompt TEXTE     remplace le premier texte (nœud « Prompt positif » ou « Instruction »)
    --negatif TEXTE    remplace le prompt négatif
    --image FICHIER    envoie l'image à ComfyUI et la branche sur le 1er nœud Load Image (répéter : 2e, 3e… ;
                       un nœud Load Image désactivé est alors réactivé)
    --seed N           graine fixe (sinon aléatoire)
    --regler "Titre du nœud:entree=valeur"   change un réglage (ex. "Génération dans la zone:denoise=1.0")
    --sortie DOSSIER   copie les images produites dans ce dossier
    --serveur URL      défaut http://127.0.0.1:8188
"""
import argparse, json, mimetypes, os, random, sys, time, urllib.error, urllib.parse, urllib.request, uuid

VIRTUELS = {"MarkdownNote", "Note", "PrimitiveStringMultiline", "Reroute"}
CHOIX_SEED = ("fixed", "randomize", "increment", "decrement")


def appel(url, donnees=None, entetes=None):
    req = urllib.request.Request(url, donnees, entetes or {})
    with urllib.request.urlopen(req) as r:
        return r.read()


def envoyer_image(serveur, chemin):
    """POST /upload/image (multipart) → nom du fichier dans le dossier input de ComfyUI."""
    limite = uuid.uuid4().hex
    nom = os.path.basename(chemin)
    type_mime = mimetypes.guess_type(nom)[0] or "application/octet-stream"
    with open(chemin, "rb") as f:
        contenu = f.read()
    corps = (f"--{limite}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{nom}\"\r\n"
             f"Content-Type: {type_mime}\r\n\r\n").encode() + contenu + \
            f"\r\n--{limite}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{limite}--\r\n".encode()
    rep = json.loads(appel(serveur + "/upload/image", corps, {"Content-Type": f"multipart/form-data; boundary={limite}"}))
    return rep["name"]


def convertir(wf, info, seed):
    """Format UI (nœuds + liens) → format API ({id: {class_type, inputs}})."""
    noeuds = {n["id"]: n for n in wf["nodes"]}
    liens = {l[0]: l for l in wf["links"]}

    def source(id_lien):
        l = liens[id_lien]
        s = noeuds[l[1]]
        if s["type"] == "PrimitiveStringMultiline":
            return s["widgets_values"][0]
        if s.get("mode") == 4:  # nœud contourné (bypass) : on suit son entrée de même type, s'il y en a une
            for e in s.get("inputs", []):
                if e["type"] == l[5] and e.get("link") is not None:
                    return source(e["link"])
            return None
        if s.get("mode") == 2:  # nœud coupé (mute)
            return None
        return [str(l[1]), l[2]]

    prompt = {}
    for n in noeuds.values():
        if n["type"] in VIRTUELS or n.get("mode") in (2, 4):
            continue
        if n["type"] not in info:
            sys.exit(f"Nœud inconnu de ce ComfyUI : {n['type']} (nœud {n['id']}). Version trop ancienne ou nœud tiers manquant.")
        spec = info[n["type"]]["input"]
        ordre = list(spec.get("required", {}).items()) + list(spec.get("optional", {}).items())
        liens_entree = {e["name"]: e["link"] for e in n.get("inputs", []) if e.get("link") is not None}
        w = list(n.get("widgets_values") or [])
        entrees = {}
        for nom, cfg in ordre:
            t = cfg[0]
            est_widget = isinstance(t, list) or t in ("INT", "FLOAT", "STRING", "BOOLEAN", "COMBO")
            if est_widget and w:
                entrees[nom] = w.pop(0)
                if nom in ("seed", "noise_seed") and w and w[0] in CHOIX_SEED:
                    w.pop(0)  # le choix « control after generate » n'est pas une entrée
                if n["type"] == "LoadImage" and nom == "image" and w and w[0] == "image":
                    w.pop(0)  # bouton « upload » du nœud Load Image
            if nom in liens_entree:
                v = source(liens_entree[nom])
                if v is None:
                    entrees.pop(nom, None)
                else:
                    entrees[nom] = v
        if "seed" in entrees:
            entrees["seed"] = seed
        if "noise_seed" in entrees and entrees.get("add_noise", "enable") == "enable":
            entrees["noise_seed"] = seed
        prompt[str(n["id"])] = {"class_type": n["type"], "inputs": entrees, "_meta": {"title": n.get("title") or n["type"]}}
    return prompt


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("workflow")
    p.add_argument("--prompt")
    p.add_argument("--negatif")
    p.add_argument("--image", action="append", default=[])
    p.add_argument("--seed", type=int)
    p.add_argument("--regler", action="append", default=[])
    p.add_argument("--sortie")
    p.add_argument("--serveur", default="http://127.0.0.1:8188")
    a = p.parse_args()

    try:
        info = json.loads(appel(a.serveur + "/object_info"))
    except (urllib.error.URLError, ConnectionError):
        sys.exit(f"ComfyUI ne répond pas sur {a.serveur} : le lancer d'abord (scripts\\lancer-comfyui.ps1).")

    with open(a.workflow, encoding="utf-8") as f:
        wf = json.load(f)
    noeuds = sorted(wf["nodes"], key=lambda n: n["id"])
    textes = [n for n in noeuds if n["type"] == "PrimitiveStringMultiline"]
    if a.prompt is not None:
        cible = next((n for n in textes if "gatif" not in (n.get("title") or "")), None)
        if cible is None:
            sys.exit("Pas de nœud de prompt (PrimitiveStringMultiline) dans ce workflow.")
        cible["widgets_values"][0] = a.prompt
    if a.negatif is not None:
        cible = next((n for n in textes if "gatif" in (n.get("title") or "")), None)
        if cible is None:
            sys.exit("Pas de nœud « Prompt négatif » dans ce workflow.")
        cible["widgets_values"][0] = a.negatif
    chargeurs = sorted([n for n in noeuds if n["type"] == "LoadImage"], key=lambda n: n["pos"][1])
    if len(a.image) > len(chargeurs):
        sys.exit(f"{len(a.image)} image(s) fournie(s) mais seulement {len(chargeurs)} nœud(s) Load Image.")
    for chemin, n in zip(a.image, chargeurs):
        n["widgets_values"][0] = envoyer_image(a.serveur, chemin)
        n["mode"] = 0

    seed = a.seed if a.seed is not None else random.randint(0, 2**48)
    prompt = convertir(wf, info, seed)

    for r in a.regler:
        titre, _, reste = r.partition(":")
        cle, _, valeur = reste.partition("=")
        ids = [i for i, v in prompt.items() if v["_meta"]["title"] == titre]
        if not ids or cle not in prompt[ids[0]]["inputs"]:
            sys.exit(f"Réglage introuvable : {r}")
        ancien = prompt[ids[0]]["inputs"][cle]
        prompt[ids[0]]["inputs"][cle] = type(ancien)(valeur) if isinstance(ancien, (int, float)) and not isinstance(ancien, bool) else valeur

    corps = json.dumps({"prompt": prompt, "client_id": uuid.uuid4().hex}).encode()
    try:
        pid = json.loads(appel(a.serveur + "/prompt", corps, {"Content-Type": "application/json"}))["prompt_id"]
    except urllib.error.HTTPError as e:
        sys.exit("ComfyUI a refusé le workflow :\n" + e.read().decode(errors="replace")[:3000])

    print(f"Envoyé ({os.path.basename(a.workflow)}, seed {seed})…", flush=True)
    t0 = time.time()
    while True:
        time.sleep(1)
        h = json.loads(appel(f"{a.serveur}/history/{pid}"))
        if pid in h:
            break
    h = h[pid]
    statut = h["status"]["status_str"]
    images = [i for o in h["outputs"].values() for i in o.get("images", []) if i.get("type") == "output"]
    print(f"{statut} en {time.time() - t0:.0f} s")
    if statut != "success":
        for m in h["status"].get("messages", []):
            if m[0] == "execution_error":
                print(m[1].get("exception_message", m[1]))
        sys.exit(1)
    for i in images:
        print("  output\\" + (i["subfolder"] + "\\" if i["subfolder"] else "") + i["filename"])
        if a.sortie:
            os.makedirs(a.sortie, exist_ok=True)
            q = urllib.parse.urlencode({"filename": i["filename"], "subfolder": i["subfolder"], "type": "output"})
            with open(os.path.join(a.sortie, i["filename"]), "wb") as f:
                f.write(appel(f"{a.serveur}/view?{q}"))


if __name__ == "__main__":
    main()
