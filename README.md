# IReader

Lector de documentos y biblioteca para **iPad mini 1 (iOS 9.3.6, armv7)**.

IReader abre practicamente cualquier archivo y lo muestra **tal cual es**: sin
cambiar la tipografia, los margenes ni el tamano de pagina. Guarda la posicion
exacta de lectura y la recupera al volver a abrir, incluso despues de cerrar la
app a la fuerza.

Toda la interfaz es propia (sin `UIAlertController`, sin `UIActionSheet`, sin
`UIDocumentPickerViewController`): dialogos, hojas, avisos y explorador de
archivos estan escritos desde cero.

## Formatos

| Grupo | Extensiones | Como se muestra |
|-------|-------------|-----------------|
| PDF | `pdf` | Render exacto por pagina con `CGPDFDocument` y `CATiledLayer` |
| EPUB | `epub` | CSS y fuentes originales, sin reflujo por defecto |
| Office | `docx`, `xlsx`, `pptx` | Contenido y diseno del documento original |
| HTML | `html`, `htm`, `svg` | Maquetacion original tal cual |
| Texto | `txt`, `md`, `rtf`, `csv`, `json`, `xml`, codigo | Paginacion real con TextKit |
| Imagenes | `png`, `jpg`, `jpeg`, `gif`, `bmp`, `tif`, `tiff`, `webp` | Ajuste y zoom, sin reescalado del archivo |
| Comics | `cbz` | Una pagina por imagen |
| Multimedia | `mp3`, `m4a`, `aac`, `wav`, `mp4`, `mov`, `m4v` | Reproductor propio |
| Desconocido | cualquier otra | Visor hexadecimal con salto a posicion |

`doc`, `xls` y `ppt` (Office 97) no se reconstruyen con fidelidad: IReader lo
avisa y recomienda exportarlos a PDF. CBR, MOBI, AZW3 y DJVU no estan incluidos
en la version 1.0.

## Funciones

- **Biblioteca** con portadas, colecciones, favoritos, busqueda y orden.
- **Lector PDF** con zoom, miniaturas, indice, marcadores, notas, contrasena y
  modo noche por inversion.
- **Lector de texto** paginado con TextKit y modo de desplazamiento para
  archivos muy grandes.
- **Marcadores y notas** en PDF, EPUB, texto, comics y hex.
- **Indice y busqueda** dentro del documento cuando el formato lo permite.
- **Temas de lectura**: Original, Papel, Sepia, Noche y Negro.
- **Dos paginas** y ajuste de tipografia.
- **Estadisticas** de lectura por documento.
- **Servidor Wi-Fi** propio para subir archivos desde el ordenador.
- **Importacion** por explorador interno, cable (AFC), iTunes y "Abrir con".

## Guardado de la posicion

Cada formato guarda lo que necesita para reanudar exactamente donde se dejo:

- PDF: pagina, zoom y desplazamiento.
- EPUB y HTML: capitulo y ancla de texto.
- Texto: desplazamiento de caracteres.
- Imagenes y CBZ: indice de pagina y zoom.
- Office: pagina o diapositiva y proporcion.
- Multimedia: segundo exacto.
- Hex: desplazamiento en bytes.

Se guarda al pasar a segundo plano, al recibir memoria baja, al cerrar el
documento y cada 30 segundos de lectura.

## Compilar

El proyecto se compila sin Mac usando [Theos](https://theos.dev) y un toolchain
`clang` para armv7 contra el SDK de iOS 9.3.

```sh
cd app
make clean
make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
```

El `.ipa` queda en `app/packages/`.

### GitHub Actions

`.github/workflows/build-ipa.yml` instala Theos, el toolchain y el SDK, genera
los iconos, compila y publica el `.ipa` como artefacto y como Release. Se
ejecuta al subir a `main` o a mano desde "Run workflow".

## Instalar

1. Descarga el `.ipa` del ultimo
   [Release](https://github.com/lofturb/ireader/releases/latest) o de los
   artefactos del flujo.
2. Instalalo con AltStore, Sideloadly o `ideviceinstaller`:
   ```sh
   ideviceinstaller -i IReader.ipa
   ```
3. Si la firma es local, necesitas AppSync Unified.

## Estructura

```
app/                 Codigo de la app (Objective-C, ARC, sin storyboards)
  Resources/         Iconos e imagenes de arranque
  Makefile           Definicion de Theos
tools/               Utilidades de desarrollo
  comprobar_fuentes.py   Valida fuentes, metadatos y APIs prohibidas
  generar_recursos.py    Regenera iconos y arranques
  generar_muestras.py    Crea documentos de prueba en tests/muestras
  verificar_ipa.py       Comprueba un .ipa ya empaquetado
  afc_put.py             Copia archivos al iPad por USB
tests/muestras/      Documentos de prueba de todos los formatos
.github/workflows/   Compilacion continua
```

## Pruebas

```sh
python tools/comprobar_fuentes.py     # valida el codigo antes de compilar
python tools/generar_muestras.py      # crea documentos de ejemplo
python tools/verificar_ipa.py ruta/al/IReader.ipa
```

## Licencia

MIT. Consulta [LICENSE](LICENSE) y [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
