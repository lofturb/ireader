# -*- coding: utf-8 -*-
"""Comprueba fuentes, Makefile, metadatos y API prohibida antes de compilar.

Uso:
    python tools/comprobar_fuentes.py
"""

import io
import os
import plistlib
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(RAIZ, "app")
MAKEFILE = os.path.join(APP, "Makefile")
CONTROL = os.path.join(APP, "control")
INFO = os.path.join(APP, "Resources", "Info.plist")

# IReader debe usar solo su propia interfaz.
PROHIBIDAS = [
    "UIAlertController",
    "UIAlertView",
    "UIActionSheet",
    "UIActivityViewController",
    "QLPreviewController",
    "UIDocumentPickerViewController",
    "UIDocumentInteractionController",
    "UIMenuController",
    "UISearchDisplayController",
    "UISearchController",
    "UIImagePickerController",
    "UIPasteboard",
    "UIReferenceLibraryViewController",
]

problemas = 0


def error(texto):
    global problemas
    problemas += 1
    print("  ERROR: %s" % texto)


def aviso(texto):
    print("  AVISO: %s" % texto)


def leer(ruta):
    with io.open(ruta, encoding="utf-8") as archivo:
        return archivo.read()


def sin_comentarios(texto):
    texto = re.sub(r"/\*.*?\*/", "", texto, flags=re.S)
    texto = re.sub(r"//[^\n]*", "", texto)
    return texto


def main():
    if not os.path.isfile(MAKEFILE):
        error("no existe app/Makefile")
        return 1

    makefile = leer(MAKEFILE)
    coincidencia = re.search(r"^\s*APPLICATION_NAME\s*=\s*(\S+)\s*$", makefile, re.M)
    if not coincidencia:
        error("no se encontro APPLICATION_NAME")
        return 1
    app = coincidencia.group(1)
    print("Aplicacion: %s" % app)

    en_disco = sorted(n for n in os.listdir(APP)
                      if n.endswith(".m") and os.path.isfile(os.path.join(APP, n)))
    declaradas = re.findall(r"(%s_FILES\s*=.*?)(?:\n[A-Za-z_]+\s*=|include|$)" % re.escape(app),
                            makefile, re.S)
    fuentes = set()
    for bloque in declaradas:
        for nombre in bloque.replace("\\\n", " ").split():
            if nombre.endswith(".m"):
                fuentes.add(nombre)

    print("Fuentes en disco: %d" % len(en_disco))
    for nombre in en_disco:
        if nombre not in fuentes:
            error("%s esta en app/ pero no en %s_FILES" % (nombre, app))
        ruta = os.path.join(APP, nombre)
        if os.path.getsize(ruta) == 0:
            error("%s esta vacio" % nombre)

    print("")
    print("=== Metadatos ===")
    try:
        with io.open(INFO, "rb") as archivo:
            info = plistlib.load(archivo)
    except Exception as excepcion:
        error("no se pudo leer Info.plist: %s" % excepcion)
        info = {}

    control = leer(CONTROL)
    paquete = re.search(r"^Package:\s*(\S+)", control, re.M)
    version = re.search(r"^Version:\s*(\S+)", control, re.M)
    paquete = paquete.group(1) if paquete else None
    version = version.group(1) if version else None

    bundle = info.get("CFBundleIdentifier")
    ejecutable = info.get("CFBundleExecutable")
    print("  Bundle ID:  %s" % bundle)
    print("  Paquete:    %s" % paquete)
    print("  Ejecutable: %s" % ejecutable)
    print("  Version:    %s / %s" % (info.get("CFBundleShortVersionString"), version))
    print("  iOS minimo: %s" % info.get("MinimumOSVersion"))

    if bundle != paquete:
        error("CFBundleIdentifier y Package no coinciden")
    if ejecutable != app:
        error("CFBundleExecutable no coincide con APPLICATION_NAME")
    if not info.get("CFBundleShortVersionString"):
        error("falta CFBundleShortVersionString")
    if bundle and bundle != "com.lofturb.ireader":
        aviso("el bundle ID es %s" % bundle)

    print("")
    print("=== API prohibida ===")
    archivos = set(en_disco)
    archivos.update(n for n in os.listdir(APP) if n.endswith(".h"))
    encontradas = 0
    for nombre in sorted(archivos):
        texto = sin_comentarios(leer(os.path.join(APP, nombre)))
        for prohibida in PROHIBIDAS:
            if prohibida in texto:
                encontradas += 1
                error("%s usa %s" % (nombre, prohibida))
    if encontradas == 0:
        print("  Ninguna: todo es interfaz propia.")

    print("")
    if problemas:
        print("=== Resultado: %d problema(s) ===" % problemas)
        return 1
    print("=== Resultado: correcto ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
