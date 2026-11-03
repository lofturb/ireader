# Avisos de terceros

IReader se compila solo con las herramientas del sistema (Theos, clang,
SDK de iOS) y con codigo propio. No incluye dependencias externas en el
binario: usa `zlib` (ya presente en iOS) para ZIP y los frameworks de Apple
(UIKit, CoreText, ImageIO, AVFoundation...).

Parte del diseno y la estructura de proyecto siguen el kit `Guia-IPA-iOS9`
y el proyecto IOpenFiles, ambos del mismo autor.

El servidor Wi-Fi integrado es una implementacion propia y minima.
