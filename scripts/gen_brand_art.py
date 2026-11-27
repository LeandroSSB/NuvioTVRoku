# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
"""Gera icons + splashes nas 3 resolucoes a partir da marca oficial NuvioMedia
(assets/brand/: app_logo_mark.png 1080x1080 RGB, app_logo_wordmark.png 1085x344 RGBA).

Icon (4:3 paisagem): fundo navy (amostrado do canto do mark — costura invisivel) +
mark centrada a 72% da altura.
Splash (16:9): mesmo fundo + mark a 32% da altura no terco superior + wordmark abaixo.
Substitui os placeholders pretos originais; rodar via scripts/art-megalan.sh (Pillow
na megalan, nunca no WSL)."""
from PIL import Image, ImageChops
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BRAND = os.path.join(HERE, "..", "assets", "brand")
OUT = os.path.join(HERE, "..", "assets", "images")

ICONS = {"icon_sd.png": (246, 180), "icon_hd.png": (540, 405), "icon_fhd.png": (810, 607)}
SPLASHES = {"splash_sd.png": (720, 480), "splash_hd.png": (1280, 720), "splash_fhd.png": (1920, 1080)}


def tight_crop_rgb(im):
    """Recorta ao bounding box do conteudo (fundo uniforme amostrado no canto)."""
    bg = im.getpixel((4, 4))
    solid = Image.new("RGB", im.size, bg)
    return im.crop(ImageChops.difference(im, solid).getbbox()), bg


def tight_crop_alpha(im):
    return im.crop(im.getchannel("A").getbbox())


def paste_center(canvas, art, top):
    x = (canvas.width - art.width) // 2
    canvas.paste(art, (x, top), art if art.mode == "RGBA" else None)


def compose_icon(mark, size):
    canvas = Image.new("RGB", size, ICON_BG)
    h = int(size[1] * 0.72)
    art = mark.resize((h, h), Image.LANCZOS)
    paste_center(canvas, art, (size[1] - h) // 2)
    return canvas


def compose_splash(mark, word, size):
    canvas = Image.new("RGB", size, ICON_BG)
    mark_h = int(size[1] * 0.32)
    art = mark.resize((mark_h, mark_h), Image.LANCZOS)
    mark_top = int(size[1] * 0.24)
    paste_center(canvas, art, mark_top)
    word_w = int(size[0] * 0.26)
    word_h = int(word_w * word.height / word.width)
    paste_center(canvas, word.resize((word_w, word_h), Image.LANCZOS),
                 mark_top + mark_h + int(size[1] * 0.06))
    return canvas


mark_raw = Image.open(os.path.join(BRAND, "app_logo_mark.png")).convert("RGB")
mark, ICON_BG = tight_crop_rgb(mark_raw)
word = tight_crop_alpha(Image.open(os.path.join(BRAND, "app_logo_wordmark.png")).convert("RGBA"))

for name, size in ICONS.items():
    compose_icon(mark, size).save(os.path.join(OUT, name))
    print("ok", name, size, "bg=#%02x%02x%02x" % ICON_BG)

for name, size in SPLASHES.items():
    compose_splash(mark, word, size).save(os.path.join(OUT, name))
    print("ok", name, size)
