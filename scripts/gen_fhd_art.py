# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
"""Gera arte FHD escalando os assets HD (splash 1280x720→1920x1080, icon 540x405→810x607).
Dimensões FHD = HD x 1.5 (splash é padrão do Roku; icon segue a proporção dos placeholders).
Revalidar contra device quando chegar (imagens são escaladas pelo launcher)."""
from PIL import Image
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "assets", "images")
ALVO = {"icon_hd.png": (810, 607), "splash_hd.png": (1920, 1080)}

for src, size in ALVO.items():
    out = src.replace("_hd", "_fhd")
    im = Image.open(os.path.join(ASSETS, src)).convert("RGB").resize(size, Image.LANCZOS)
    im.save(os.path.join(ASSETS, out))
    print("ok", out, size)
