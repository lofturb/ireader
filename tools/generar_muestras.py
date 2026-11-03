#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera documentos de muestra para probar IReader.

Crea archivos de todos los formatos soportados en tests/muestras/.
Solo usa la biblioteca estandar de Python 3.

Uso:  python tools/generar_muestras.py
"""

import json
import os
import struct
import zipfile
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "tests", "muestras")


def asegurar_directorio():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)


def ruta(nombre):
    return os.path.join(DESTINO, nombre)


def escribir(nombre, datos):
    modo = "wb" if isinstance(datos, bytes) else "w"
    kwargs = {} if isinstance(datos, bytes) else {"encoding": "utf-8", "newline": "\n"}
    with open(ruta(nombre), modo, **kwargs) as f:
        f.write(datos)
    print("  %-22s %8d bytes" % (nombre, os.path.getsize(ruta(nombre))))


def png_bytes(ancho, alto, color_fondo, color_texto=None):
    """PNG RGB sencillo con un patron legible a simple vista."""
    def trozo(etiqueta, datos):
        return (struct.pack(">I", len(datos)) + etiqueta + datos +
                struct.pack(">I", zlib.crc32(etiqueta + datos) & 0xffffffff))

    filas = []
    for y in range(alto):
        fila = bytearray(b"\x00")
        for x in range(ancho):
            r, g, b = color_fondo
            # Marco y bandas diagonales para distinguir cada pagina.
            if x < 6 or y < 6 or x >= ancho - 6 or y >= alto - 6:
                r, g, b = 60, 40, 30
            elif color_texto and ((x + y) // 40) % 5 == 0:
                r, g, b = color_texto
            fila += bytes((r, g, b))
        filas.append(bytes(fila))

    crudo = b"".join(filas)
    return (b"\x89PNG\r\n\x1a\n" +
            trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0)) +
            trozo(b"IDAT", zlib.compress(crudo, 9)) +
            trozo(b"IEND", b""))


def pdf_bytes(paginas):
    """PDF 1.4 minimo con texto en Times-Roman."""
    objetos = {}
    ids_pagina = []
    ids_contenido = []
    siguiente = 4
    for _ in paginas:
        ids_pagina.append(siguiente)
        siguiente += 1
        ids_contenido.append(siguiente)
        siguiente += 1

    objetos[1] = b"<< /Type /Catalog /Pages 2 0 R >>"
    hijos = " ".join("%d 0 R" % i for i in ids_pagina)
    objetos[2] = ("<< /Type /Pages /Kids [%s] /Count %d >>"
                  % (hijos, len(ids_pagina))).encode("ascii")
    objetos[3] = (b"<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman "
                  b"/Encoding /WinAnsiEncoding >>")

    for indice, lineas in enumerate(paginas):
        pid = ids_pagina[indice]
        cid = ids_contenido[indice]
        objetos[pid] = ("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
                        "/Resources << /Font << /F1 3 0 R >> >> "
                        "/Contents %d 0 R >>" % cid).encode("ascii")
        operaciones = ["BT", "/F1 12 Tf", "64 780 Td", "20 TL"]
        for texto, tamano in lineas:
            seguro = (texto.replace("\\", "\\\\")
                           .replace("(", "\\(")
                           .replace(")", "\\)"))
            operaciones.append("/F1 %d Tf" % tamano)
            operaciones.append("(%s) Tj T*" % seguro)
        operaciones.append("ET")
        flujo = "\n".join(operaciones).encode("latin-1", "replace")
        objetos[cid] = (b"<< /Length %d >>\nstream\n" % len(flujo) +
                        flujo + b"\nendstream")

    salida = bytearray(b"%PDF-1.4\n")
    posiciones = {}
    for oid in sorted(objetos):
        posiciones[oid] = len(salida)
        salida += b"%d 0 obj\n" % oid + objetos[oid] + b"\nendobj\n"

    inicio_xref = len(salida)
    maximo = max(objetos)
    salida += b"xref\n0 %d\n" % (maximo + 1)
    salida += b"0000000000 65535 f \n"
    for oid in range(1, maximo + 1):
        if oid in posiciones:
            salida += b"%010d 00000 n \n" % posiciones[oid]
        else:
            salida += b"0000000000 65535 f \n"
    salida += (b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
               % (maximo + 1, inicio_xref))
    return bytes(salida)


def escribir_textos():
    parrafo = (
        "La lectura conserva el tamano de pagina, los margenes y la tipografia "
        "original del documento. IReader no refluye el contenido salvo que el "
        "lector lo pida expresamente, de modo que una pagina del archivo se ve "
        "igual que en el programa donde se creo."
    )
    lineas = ["IReader - documento de prueba", "=" * 34, ""]
    for i in range(1, 41):
        lineas.append("Parrafo %02d" % i)
        lineas.append(parrafo)
        lineas.append("")
        if i % 8 == 0:
            lineas.append("--- pagina sugerida %d ---" % (i // 8))
            lineas.append("")
    escribir("hola.txt", "\n".join(lineas) + "\n")

    markdown = """# Notas de lectura

## Formatos

- PDF: render exacto por pagina.
- EPUB: CSS y fuentes del libro.
- Office: DOCX, XLSX y PPTX.
- Texto: TXT, Markdown, RTF, CSV, JSON, XML y codigo.

## Lista de comprobacion

1. Abrir el documento.
2. Cambiar de pagina y cerrar la app.
3. Volver a abrir: debe recuperar la posicion.

> La posicion se guarda tambien al recibir memoria baja.

```objc
IRDocument *doc = [library documentAtIndex:0];
[reader openDocument:doc];
```

| Formato | Exacto | Reflujo |
|---------|--------|---------|
| PDF     | Si     | No      |
| EPUB    | Si     | Opcional|
| TXT     | No     | Si      |
"""
    escribir("notas.md", markdown)

    filas = ["titulo,autor,ano,paginas"]
    for i in range(1, 21):
        filas.append("Libro %02d,Autor %02d,%d,%d" % (i, i, 1900 + i, 100 + i * 7))
    escribir("datos.csv", "\n".join(filas) + "\n")

    config = {
        "aplicacion": "IReader",
        "version": "1.0.0",
        "idioma": "es",
        "formatos": ["pdf", "epub", "txt", "md", "html", "cbz"],
        "lectura": {
            "tema": "papel",
            "guardarPosicion": True,
            "dosPaginas": False,
        },
    }
    escribir("config.json", json.dumps(config, indent=2, ensure_ascii=False) + "\n")

    xml = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Biblioteca de prueba</title>
  <updated>2026-01-01T00:00:00Z</updated>
  <entry>
    <title>Primer documento</title>
    <summary>Un resumen corto para comprobar el visor XML.</summary>
  </entry>
  <entry>
    <title>Segundo documento</title>
    <summary>Otro resumen con acentos: cancion, nino, arbol.</summary>
  </entry>
</feed>
"""
    escribir("feed.xml", xml)

    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Pagina de prueba</title>
<style>
  @page { size: A5; margin: 18mm; }
  body { font-family: Georgia, serif; color: #2a2118; background: #fbf6ec;
         margin: 0; padding: 18mm; line-height: 1.6; }
  h1 { font-size: 26pt; margin: 0 0 8pt 0; letter-spacing: -0.5pt; }
  h2 { font-size: 15pt; margin: 20pt 0 6pt 0; color: #8a4b2a; }
  p  { font-size: 12pt; text-align: justify; margin: 0 0 9pt 0; }
  .nota { border-left: 3pt solid #b4552d; padding-left: 10pt; color: #5a4a3a; }
</style>
</head>
<body>
<h1>Pagina con estilo propio</h1>
<p>Este archivo conserva su tipografia serif, sus margenes de 18 mm y el
tamano de hoja A5. IReader lo muestra tal cual, sin reflujo.</p>
<h2>Segunda seccion</h2>
<p class="nota">Si el lector cambia el tema de lectura, el contenido puede
adaptarse, pero el diseno original sigue disponible.</p>
</body>
</html>
"""
    escribir("pagina.html", html)

    svg = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">
  <rect width="600" height="400" fill="#fbf6ec"/>
  <circle cx="300" cy="200" r="140" fill="#b4552d" opacity="0.15"/>
  <path d="M150 260 L300 120 L450 260 Z" fill="none" stroke="#8a4b2a" stroke-width="6"/>
  <text x="300" y="330" font-family="Georgia, serif" font-size="28"
        text-anchor="middle" fill="#2a2118">IReader</text>
</svg>
"""
    escribir("dibujo.svg", svg)

    rtf = (r"{\rtf1\ansi\deff0{\fonttbl{\f0\froman Times New Roman;}}"
           "\n" r"\f0\fs28 IReader: documento RTF" "\n"
           r"\par\fs22 Este texto usa Times New Roman y conserva sus margenes." "\n"
           r"\par\fs22 Segunda linea de prueba para comprobar el ajuste." "\n" "}")
    escribir("carta.rtf", rtf)


def escribir_epub():
    opf = """<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:ireader-muestra-0001</dc:identifier>
    <dc:title>Libro de muestra</dc:title>
    <dc:language>es</dc:language>
    <dc:creator>IReader</dc:creator>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="css" href="estilo.css" media-type="text/css"/>
    <item id="c1" href="capitulo1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="capitulo2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
"""
    nav = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Indice</title></head>
<body>
<nav epub:type="toc" id="toc">
  <h1>Indice</h1>
  <ol>
    <li><a href="capitulo1.xhtml">Capitulo primero</a></li>
    <li><a href="capitulo2.xhtml">Capitulo segundo</a></li>
  </ol>
</nav>
</body>
</html>
"""
    css = """@charset "utf-8";
body { font-family: Georgia, serif; margin: 8%; line-height: 1.65; color: #2a2118; }
h1 { font-size: 1.7em; margin: 0 0 0.6em 0; color: #8a4b2a; }
p { text-align: justify; text-indent: 1.4em; margin: 0 0 0.7em 0; }
"""
    capitulo1 = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Capitulo primero</title>
<link rel="stylesheet" type="text/css" href="estilo.css"/></head>
<body>
<h1>Capitulo primero</h1>
<p>Este EPUB conserva su hoja de estilo, su tipografia serif y sus margenes.
IReader lo muestra tal cual, sin reflujo por defecto.</p>
<p>El lector puede cambiar el tamano del texto y el tema, pero la vista
original siempre esta a un toque de distancia.</p>
</body>
</html>
"""
    capitulo2 = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Capitulo segundo</title>
<link rel="stylesheet" type="text/css" href="estilo.css"/></head>
<body>
<h1>Capitulo segundo</h1>
<p>La posicion de lectura se guarda por capitulo y por texto visible, de modo
que al volver a abrir el libro se recupera el mismo parrafo.</p>
<p>Tambien se pueden anadir marcadores con notas desde el menu del lector.</p>
</body>
</html>
"""
    container = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
    with zipfile.ZipFile(ruta("libro.epub"), "w") as z:
        z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip",
                   compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", container, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/content.opf", opf, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/nav.xhtml", nav, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/estilo.css", css, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/capitulo1.xhtml", capitulo1, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/capitulo2.xhtml", capitulo2, compress_type=zipfile.ZIP_DEFLATED)
    print("  %-22s %8d bytes" % ("libro.epub", os.path.getsize(ruta("libro.epub"))))


def escribir_cbz():
    comic = """<?xml version="1.0" encoding="UTF-8"?>
<ComicInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>Comic de muestra</Title>
  <Series>IReader</Series>
  <Number>1</Number>
  <PageCount>3</PageCount>
</ComicInfo>
"""
    with zipfile.ZipFile(ruta("album.cbz"), "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("ComicInfo.xml", comic)
        colores = [(251, 246, 236), (246, 236, 220), (236, 226, 210)]
        for i, fondo in enumerate(colores, start=1):
            z.writestr("pagina%02d.png" % i, png_bytes(600, 800, fondo, (180, 85, 45)))
    print("  %-22s %8d bytes" % ("album.cbz", os.path.getsize(ruta("album.cbz"))))


def escribir_docx():
    tipos = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"""
    documento = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p><w:pPr><w:pStyle w:val="Titulo"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="40"/></w:rPr><w:t>Informe de prueba</w:t></w:r></w:p>
<w:p><w:r><w:t>Este DOCX conserva sus estilos, su fuente y sus margenes.</w:t></w:r></w:p>
<w:p><w:r><w:t>IReader extrae el contenido y lo muestra con el diseno del documento.</w:t></w:r></w:p>
<w:p><w:r><w:t>Segundo parrafo con texto suficiente para comprobar el desplazamiento.</w:t></w:r></w:p>
</w:body>
</w:document>
"""
    with zipfile.ZipFile(ruta("informe.docx"), "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", tipos)
        z.writestr("_rels/.rels", rels)
        z.writestr("word/document.xml", documento)
    print("  %-22s %8d bytes" % ("informe.docx", os.path.getsize(ruta("informe.docx"))))


def escribir_xlsx():
    tipos = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>
"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
"""
    libro = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Ventas" sheetId="1" r:id="rId1"/></sheets>
</workbook>
"""
    rels_libro = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>
"""
    filas = ["<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Mes</t></is></c>"
             "<c r=\"B1\" t=\"inlineStr\"><is><t>Ventas</t></is></c></row>"]
    meses = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio"]
    for i, mes in enumerate(meses, start=2):
        filas.append("<row r=\"%d\"><c r=\"A%d\" t=\"inlineStr\"><is><t>%s</t></is></c>"
                     "<c r=\"B%d\"><v>%d</v></c></row>" % (i, i, mes, i, 1000 + i * 137))
    hoja = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            "<sheetData>" + "".join(filas) + "</sheetData></worksheet>\n")
    with zipfile.ZipFile(ruta("hoja.xlsx"), "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", tipos)
        z.writestr("_rels/.rels", rels)
        z.writestr("xl/workbook.xml", libro)
        z.writestr("xl/_rels/workbook.xml.rels", rels_libro)
        z.writestr("xl/worksheets/sheet1.xml", hoja)
    print("  %-22s %8d bytes" % ("hoja.xlsx", os.path.getsize(ruta("hoja.xlsx"))))


def escribir_pptx():
    tipos = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>
"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>
"""
    presentacion = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
<p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst>
<p:sldSz cx="9144000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
"""
    rels_presentacion = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
"""
    diapositiva = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>
<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
<p:sp><p:nvSpPr><p:cNvPr id="2" name="Titulo"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="838200" y="365125"/><a:ext cx="7772400" cy="1325563"/></a:xfrm></p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="es-ES" sz="4400"/><a:t>Charla de prueba</a:t></a:r></a:p></p:txBody></p:sp>
<p:sp><p:nvSpPr><p:cNvPr id="3" name="Texto"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="838200" y="1825625"/><a:ext cx="7772400" cy="4351338"/></a:xfrm></p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/>
<a:p><a:r><a:rPr lang="es-ES" sz="2400"/><a:t>Diapositiva con texto y diseno original.</a:t></a:r></a:p>
<a:p><a:r><a:rPr lang="es-ES" sz="2400"/><a:t>IReader muestra cada diapositiva como una pagina.</a:t></a:r></a:p>
</p:txBody></p:sp>
</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
"""
    rels_diapositiva = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>
"""
    diseno = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
<p:cSld name="En blanco"><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>
<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
"""
    rels_diseno = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>
"""
    maestro = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>
<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree></p:cSld>
<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2"
 accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6"
 hlink="hlink" folHlink="folHlink"/>
<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
</p:sldMaster>
"""
    rels_maestro = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>
"""
    tema = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="IReader">
<a:themeElements>
<a:clrScheme name="IReader">
<a:dk1><a:srgbClr val="2A2118"/></a:dk1><a:lt1><a:srgbClr val="FBF6EC"/></a:lt1>
<a:dk2><a:srgbClr val="5A4A3A"/></a:dk2><a:lt2><a:srgbClr val="F1E7D6"/></a:lt2>
<a:accent1><a:srgbClr val="B4552D"/></a:accent1><a:accent2><a:srgbClr val="8A4B2A"/></a:accent2>
<a:accent3><a:srgbClr val="6E8B5B"/></a:accent3><a:accent4><a:srgbClr val="C9A227"/></a:accent4>
<a:accent5><a:srgbClr val="4A6C8A"/></a:accent5><a:accent6><a:srgbClr val="8A4A5A"/></a:accent6>
<a:hlink><a:srgbClr val="4A6C8A"/></a:hlink><a:folHlink><a:srgbClr val="8A4A5A"/></a:folHlink>
</a:clrScheme>
<a:fontScheme name="IReader">
<a:majorFont><a:latin typeface="Georgia"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Georgia"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="IReader">
<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
<a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
</a:theme>
"""
    with zipfile.ZipFile(ruta("charla.pptx"), "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", tipos)
        z.writestr("_rels/.rels", rels)
        z.writestr("ppt/presentation.xml", presentacion)
        z.writestr("ppt/_rels/presentation.xml.rels", rels_presentacion)
        z.writestr("ppt/slides/slide1.xml", diapositiva)
        z.writestr("ppt/slides/_rels/slide1.xml.rels", rels_diapositiva)
        z.writestr("ppt/slideLayouts/slideLayout1.xml", diseno)
        z.writestr("ppt/slideLayouts/_rels/slideLayout1.xml.rels", rels_diseno)
        z.writestr("ppt/slideMasters/slideMaster1.xml", maestro)
        z.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", rels_maestro)
        z.writestr("ppt/theme/theme1.xml", tema)
    print("  %-22s %8d bytes" % ("charla.pptx", os.path.getsize(ruta("charla.pptx"))))


def escribir_pdf():
    paginas = [
        [
            ("IReader - PDF de prueba", 22),
            ("", 12),
            ("Este archivo tiene cuatro paginas y conserva su tamano A4,", 12),
            ("sus margenes de 64 puntos y la fuente Times-Roman original.", 12),
            ("", 12),
            ("Cada pagina se dibuja con CGPDFDocument, sin reflujo.", 12),
            ("El zoom y el desplazamiento tambien se guardan.", 12),
        ],
        [
            ("Segunda pagina", 18),
            ("", 12),
            ("La posicion de lectura se guarda al pasar a segundo plano,", 12),
            ("al recibir memoria baja y al cerrar el documento.", 12),
            ("", 12),
            ("Al volver a abrir el PDF se recupera la misma pagina.", 12),
        ],
        [
            ("Tercera pagina", 18),
            ("", 12),
            ("Los marcadores guardan la pagina y una nota opcional.", 12),
            ("El indice del PDF aparece en el menu del lector.", 12),
            ("", 12),
            ("El modo noche invierte los colores sin alterar el contenido.", 12),
        ],
        [
            ("Cuarta pagina", 18),
            ("", 12),
            ("Fin del documento de prueba.", 12),
            ("", 12),
            ("Formatos: PDF, EPUB, Office, HTML, texto, imagenes, CBZ y mas.", 12),
        ],
    ]
    escribir("muestra.pdf", pdf_bytes(paginas))


def escribir_imagen():
    escribir("imagen.png", png_bytes(1200, 1600, (251, 246, 236), (180, 85, 45)))


def main():
    asegurar_directorio()
    print("Generando muestras en %s" % DESTINO)
    escribir_textos()
    escribir_epub()
    escribir_cbz()
    escribir_docx()
    escribir_xlsx()
    escribir_pptx()
    escribir_pdf()
    escribir_imagen()
    archivos = sorted(os.listdir(DESTINO))
    print("Listo: %d archivos" % len(archivos))


if __name__ == "__main__":
    main()


