# -*- coding: utf-8 -*-
"""Genera el icono de IReader y las imagenes de arranque, sin dependencias externas."""

import io
import math
import os
import struct
import sys
import zlib

TERRACOTA = (0xB4, 0x55, 0x2F, 255)
PAPEL = (0xF6, 0xF1, 0xE7, 255)
TINTA = (0x23, 0x1F, 0x1A, 255)
NOCHE = (0x16, 0x13, 0x10, 255)
VACIO = (0, 0, 0, 0)
SUPER = 3


def raiz_proyecto():
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def escribir_png(ruta, ancho, alto, pixeles):
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos +
                struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n" +
                 bloque(b"IHDR", cabecera) +
                 bloque(b"IDAT", zlib.compress(crudo, 9)) +
                 bloque(b"IEND", b""))
    with io.open(ruta, "wb") as archivo:
        archivo.write(contenido)


def dentro_rect_redondeado(x, y, lado, radio):
    if x < 0 or x > lado or y < 0 or y > lado:
        return False
    cx = min(max(x, radio), lado - radio)
    cy = min(max(y, radio), lado - radio)
    dx = x - cx
    dy = y - cy
    return dx * dx + dy * dy <= radio * radio


def dentro_del_libro(u, v):
    """Libro abierto centrado, con u y v entre 0 y 1."""
    if v < 0.20 or v > 0.80:
        return False
    if abs(u - 0.5) < 0.030:
        return True
    rel = (v - 0.20) / 0.60
    if u < 0.5:
        frac = (0.470 - u) / 0.380
    else:
        frac = (u - 0.530) / 0.380
    if frac < 0.0 or frac > 1.0:
        return False
    caida = 0.060 * math.sin(frac * math.pi)
    if v < 0.20 + caida or v > 0.80 - caida:
        return False
    if 0.16 < rel < 0.84 and int(rel * 22) % 3 == 0:
        if frac > 0.10 and frac < 0.92:
            return False
    return True


def icono(n, fondo, acento):
    salida = bytearray(n * n * 4)
    radio = 0.2237 * n
    sim = n * 0.70
    ox = (n - sim) / 2.0
    oy = (n - sim) / 2.0
    for y in range(n):
        for x in range(n):
            acc = [0, 0, 0, 0]
            cuenta = 0
            for sy in range(SUPER):
                for sx in range(SUPER):
                    px = x + (sx + 0.5) / SUPER
                    py = y + (sy + 0.5) / SUPER
                    if not dentro_rect_redondeado(px, py, n, radio):
                        continue
                    u = (px - ox) / sim
                    v = (py - oy) / sim
                    color = acento if dentro_del_libro(u, v) else fondo
                    for i in range(4):
                        acc[i] += color[i]
                    cuenta += 1
            if cuenta == 0:
                continue
            base = (y * n + x) * 4
            for i in range(4):
                salida[base + i] = int(round(acc[i] / cuenta))
    return salida


def arranque(ancho, alto):
    salida = bytearray()
    for _ in range(ancho * alto):
        salida += bytes(NOCHE)
    lado = int(min(ancho, alto) * 0.34)
    ox = (ancho - lado) // 2
    oy = (alto - lado) // 2
    marcas = int(lado * 0.70)
    mx = ox + (lado - marcas) // 2
    my = oy + (lado - marcas) // 2
    for y in range(marcas):
        for x in range(marcas):
            u = x / float(marcas)
            v = y / float(marcas)
            if dentro_del_libro(u, v):
                base = ((my + y) * ancho + (mx + x)) * 4
                salida[base:base + 4] = bytes(PAPEL)
    return salida


ICONOS = [
    ("Icon-Small.png", 29),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small-40.png", 40),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-72.png", 72),
    ("Icon-72@2x.png", 144),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("Icon-83.5.png", 167),
    ("Icon-83.5@2x.png", 334),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    raiz = raiz_proyecto()
    destino = os.path.join(raiz, "app", "Resources")
    if not os.path.isdir(destino):
        os.makedirs(destino)
    hechos = []
    for nombre, lado in ICONOS:
        print("  icono %s %dx%d" % (nombre, lado, lado))
        escribir_png(os.path.join(destino, nombre), lado, lado, icono(lado, TERRACOTA, PAPEL))
        hechos.append("%s %dx%d" % (nombre, lado, lado))
    for nombre, ancho, alto in ARRANQUES:
        print("  arranque %s %dx%d" % (nombre, ancho, alto))
        escribir_png(os.path.join(destino, nombre), ancho, alto, arranque(ancho, alto))
        hechos.append("%s %dx%d" % (nombre, ancho, alto))
    print("Generados %d archivos en app/Resources" % len(hechos))


if __name__ == "__main__":
    main()
