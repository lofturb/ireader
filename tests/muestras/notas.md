# Notas de lectura

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
