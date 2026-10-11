"""Captures d'écran de l'interface ComfyUI pour la documentation (images\\captures\\).

Pilote Chrome ou Edge en mode headless par le protocole DevTools, avec un client websocket minimal (bibliothèque
standard seulement). Pour chaque workflow : chargement dans l'interface, lancement (comme le bouton Run), attente de la
fin, capture. ComfyUI doit tourner.

Usage : python captures.py [--serveur http://127.0.0.1:8188] [--navigateur chemin\\chrome.exe] [--sans-generation]
"""
import argparse, base64, glob, json, os, socket, struct, subprocess, sys, tempfile, time, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAVIGATEURS = [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
               r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"]


class WebSocket:
    """Client websocket minimal (RFC 6455) : trames texte masquées, réassemblage des fragments."""

    def __init__(self, url):
        hote, _, chemin = url[len("ws://"):].partition("/")
        h, _, p = hote.partition(":")
        self.s = socket.create_connection((h, int(p)))
        cle = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET /{chemin} HTTP/1.1\r\nHost: {hote}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                        f"Sec-WebSocket-Key: {cle}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        rep = b""
        while b"\r\n\r\n" not in rep:
            rep += self.s.recv(1)
        if b" 101 " not in rep.split(b"\r\n")[0]:
            raise RuntimeError(rep.decode(errors="replace"))
        self.n = 0

    def _lire(self, n):
        b = b""
        while len(b) < n:
            m = self.s.recv(n - len(b))
            if not m:
                raise ConnectionError("websocket fermé")
            b += m
        return b

    def envoyer(self, texte):
        d = texte.encode()
        masque = os.urandom(4)
        entete = bytes([0x81])
        if len(d) < 126:
            entete += bytes([0x80 | len(d)])
        elif len(d) < 65536:
            entete += bytes([0x80 | 126]) + struct.pack(">H", len(d))
        else:
            entete += bytes([0x80 | 127]) + struct.pack(">Q", len(d))
        self.s.sendall(entete + masque + bytes(c ^ masque[i % 4] for i, c in enumerate(d)))

    def recevoir(self):
        message = b""
        while True:
            b0, b1 = self._lire(2)
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._lire(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._lire(8))[0]
            message += self._lire(n)
            if b0 & 0x80:
                return message.decode()

    def cdp(self, methode, **params):
        self.n += 1
        self.envoyer(json.dumps({"id": self.n, "method": methode, "params": params}))
        while True:
            r = json.loads(self.recevoir())
            if r.get("id") == self.n:
                if "error" in r:
                    raise RuntimeError(r["error"])
                return r.get("result", {})

    def js(self, code, attendre=True):
        r = self.cdp("Runtime.evaluate", expression=code, awaitPromise=attendre, returnByValue=True)
        if "exceptionDetails" in r:
            raise RuntimeError(r["exceptionDetails"])
        return r.get("result", {}).get("value")


def capturer(ws, chemin):
    png = base64.b64decode(ws.cdp("Page.captureScreenshot", format="png")["data"])
    with open(chemin, "wb") as f:
        f.write(png)
    print("   ", os.path.relpath(chemin, RACINE))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--serveur", default="http://127.0.0.1:8188")
    p.add_argument("--navigateur")
    p.add_argument("--sans-generation", action="store_true")
    a = p.parse_args()
    nav = a.navigateur or next((n for n in NAVIGATEURS if os.path.exists(n)), None)
    if not nav:
        sys.exit("Chrome ou Edge introuvable (--navigateur).")
    sortie = os.path.join(RACINE, "images", "captures")
    os.makedirs(sortie, exist_ok=True)

    profil = tempfile.mkdtemp(prefix="captures-comfyui-")
    port = 9333
    proc = subprocess.Popen([nav, "--headless=new", f"--remote-debugging-port={port}", f"--user-data-dir={profil}",
                             "--window-size=1920,1080", "--hide-scrollbars", "--no-first-run", "about:blank"])
    try:
        for _ in range(50):
            try:
                pages = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json"))
                break
            except OSError:
                time.sleep(0.2)
        ws = WebSocket(next(pg for pg in pages if pg["type"] == "page")["webSocketDebuggerUrl"])
        ws.cdp("Page.enable")
        ws.cdp("Emulation.setDeviceMetricsOverride", width=1920, height=1080, deviceScaleFactor=1, mobile=False)
        ws.cdp("Page.navigate", url=a.serveur)
        for _ in range(120):
            time.sleep(0.5)
            if ws.js("!!(window.app && window.app.graph)", False):
                break
        time.sleep(3)
        # Fermer les fenêtres d'accueil éventuelles (modèles de workflows, nouveautés)
        ws.js("document.querySelectorAll('.p-dialog-close-button, .p-dialog-header-close').forEach(b => b.click())", False)
        # Pas de minicarte, et textes des nœuds affichés même en zoom arrière (sinon mode « basse qualité » sous ~57 %)
        ws.js("window.app.extensionManager.setting.set('Comfy.Minimap.Visible', false)")
        ws.js("window.app.canvas._lowQualityZoomThreshold = 0.05", False)
        time.sleep(1)

        for f in sorted(glob.glob(os.path.join(RACINE, "workflows", "*.json"))):
            nom = os.path.splitext(os.path.basename(f))[0]
            print(nom)
            with open(f, encoding="utf-8") as fh:
                wf = json.load(fh)
            ws.js(f"window.app.loadGraphData({json.dumps(wf)}, true, true, {json.dumps(nom)})")
            time.sleep(2)
            ws.js("window.app.canvas.ds.scale = 1; window.app.graph.setDirtyCanvas(true, true)", False)
            ws.js("(() => { const c = window.app.canvas; const ns = window.app.graph._nodes;"
                  " const x0 = Math.min(...ns.map(n => n.pos[0])), y0 = Math.min(...ns.map(n => n.pos[1]));"
                  " const x1 = Math.max(...ns.map(n => n.pos[0] + n.size[0])), y1 = Math.max(...ns.map(n => n.pos[1] + n.size[1]));"
                  " const W = c.canvas.width, H = c.canvas.height;"
                  " const s = Math.min(W / (x1 - x0 + 80), (H - 60) / (y1 - y0 + 120), 1.2);"
                  " c.ds.scale = s; c.ds.offset = [-x0 + (W / s - (x1 - x0)) / 2, -y0 + 60 / s + ((H - 60) / s - (y1 - y0)) / 2];"
                  " c.setDirty(true, true); })()", False)
            time.sleep(1)
            if not a.sans_generation:
                # Lancer comme le bouton Run, puis attendre que la file soit vide
                ws.js("window.app.queuePrompt(0, 1)")
                t0 = time.time()
                time.sleep(2)
                while json.load(urllib.request.urlopen(a.serveur + "/queue"))["queue_running"]:
                    time.sleep(1)
                print(f"    généré en {time.time() - t0:.0f} s")
                time.sleep(3)
            capturer(ws, os.path.join(sortie, nom + ".png"))
    finally:
        proc.terminate()


if __name__ == "__main__":
    main()
