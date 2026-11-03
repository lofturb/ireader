#import "IRPDFOutline.h"

@implementation IRPDFOutline

+ (NSArray<IRTOCItem *> *)itemsForDocument:(CGPDFDocumentRef)document {
    NSMutableArray *salida = [NSMutableArray array];
    if (!document) return salida;
    CGPDFDictionaryRef catalogo = CGPDFDocumentGetCatalog(document);
    if (!catalogo) return salida;
    CGPDFDictionaryRef esquema = NULL;
    if (!CGPDFDictionaryGetDictionary(catalogo, "Outlines", &esquema) || !esquema) return salida;
    CGPDFDictionaryRef primero = NULL;
    if (!CGPDFDictionaryGetDictionary(esquema, "First", &primero) || !primero) return salida;
    NSInteger contador = 0;
    [self recorrer:primero documento:document nivel:0 salida:salida contador:&contador];
    return salida;
}

+ (void)recorrer:(CGPDFDictionaryRef)item
       documento:(CGPDFDocumentRef)document
           nivel:(NSInteger)nivel
          salida:(NSMutableArray *)salida
        contador:(NSInteger *)contador {
    if (!item || !contador) return;
    CGPDFDictionaryRef actual = item;
    NSInteger seguridad = 0;
    while (actual && seguridad++ < 5000 && *contador < 4000) {
        NSString *titulo = [self tituloDe:actual];
        NSInteger pagina = [self paginaDe:actual documento:document];
        if (titulo.length && pagina > 0) {
            [salida addObject:[IRTOCItem itemWithTitle:titulo
                                                  page:pagina
                                                 index:pagina - 1
                                                anchor:@""
                                                 level:nivel]];
            (*contador)++;
        }
        CGPDFDictionaryRef hijo = NULL;
        if (nivel < 12 && CGPDFDictionaryGetDictionary(actual, "First", &hijo) && hijo) {
            [self recorrer:hijo documento:document nivel:nivel + 1 salida:salida contador:contador];
        }
        CGPDFDictionaryRef siguiente = NULL;
        if (!CGPDFDictionaryGetDictionary(actual, "Next", &siguiente) || !siguiente) break;
        actual = siguiente;
    }
}

+ (NSString *)tituloDe:(CGPDFDictionaryRef)item {
    CGPDFStringRef titulo = NULL;
    if (!CGPDFDictionaryGetString(item, "Title", &titulo) || !titulo) return nil;
    CFStringRef cf = CGPDFStringCopyTextString(titulo);
    NSString *texto = CFBridgingRelease(cf);
    return [texto stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSInteger)paginaDe:(CGPDFDictionaryRef)item documento:(CGPDFDocumentRef)document {
    CGPDFObjectRef destino = NULL;
    if (!CGPDFDictionaryGetObject(item, "Dest", &destino) || !destino) {
        CGPDFDictionaryRef accion = NULL;
        if (CGPDFDictionaryGetDictionary(item, "A", &accion) && accion) {
            if (!CGPDFDictionaryGetObject(accion, "D", &destino) || !destino) return 0;
        } else {
            return 0;
        }
    }
    return [self paginaParaDestino:destino documento:document profundidad:0];
}

+ (NSInteger)paginaParaDestino:(CGPDFObjectRef)destino
                     documento:(CGPDFDocumentRef)document
                   profundidad:(NSInteger)profundidad {
    if (!destino || profundidad > 4) return 0;
    CGPDFObjectType tipo = CGPDFObjectGetType(destino);
    if (tipo == kCGPDFObjectTypeArray) {
        CGPDFArrayRef arreglo = NULL;
        if (!CGPDFObjectGetValue(destino, kCGPDFObjectTypeArray, &arreglo) || !arreglo) return 0;
        if (CGPDFArrayGetCount(arreglo) < 1) return 0;
        CGPDFObjectRef primero = NULL;
        if (!CGPDFArrayGetObject(arreglo, 0, &primero) || !primero) return 0;
        CGPDFObjectType t1 = CGPDFObjectGetType(primero);
        if (t1 == kCGPDFObjectTypeInteger) {
            CGPDFInteger indice = 0;
            if (CGPDFObjectGetValue(primero, kCGPDFObjectTypeInteger, &indice)) {
                return [self paginaParaIndice:(NSInteger)indice documento:document];
            }
        } else if (t1 == kCGPDFObjectTypeDictionary) {
            CGPDFDictionaryRef paginaDict = NULL;
            if (CGPDFObjectGetValue(primero, kCGPDFObjectTypeDictionary, &paginaDict) && paginaDict) {
                size_t total = CGPDFDocumentGetNumberOfPages(document);
                for (size_t i = 1; i <= total; i++) {
                    CGPDFPageRef p = CGPDFDocumentGetPage(document, i);
                    if (p && CGPDFPageGetDictionary(p) == paginaDict) return (NSInteger)i;
                }
            }
        }
        return 0;
    }
    if (tipo == kCGPDFObjectTypeDictionary) {
        CGPDFDictionaryRef dict = NULL;
        if (!CGPDFObjectGetValue(destino, kCGPDFObjectTypeDictionary, &dict) || !dict) return 0;
        CGPDFObjectRef d = NULL;
        if (CGPDFDictionaryGetObject(dict, "D", &d) && d) {
            return [self paginaParaDestino:d documento:document profundidad:profundidad + 1];
        }
        return 0;
    }
    return 0;
}

+ (NSInteger)paginaParaIndice:(NSInteger)indice documento:(CGPDFDocumentRef)document {
    if (indice < 0) return 0;
    size_t total = CGPDFDocumentGetNumberOfPages(document);
    if ((size_t)indice >= total) return 0;
    return indice + 1;
}

@end
