#import "IRImportManager.h"
#import "IRLibrary.h"
#import "IRMetadata.h"
#import "IRUtils.h"

NSString * const IRImportErrorDomain = @"IRImportErrorDomain";

static NSError *IRImportError(NSString *mensaje) {
    return [NSError errorWithDomain:IRImportErrorDomain code:1
                           userInfo:@{NSLocalizedDescriptionKey: mensaje ?: @"No se pudo importar el archivo"}];
}

@implementation IRImportManager

+ (instancetype)shared {
    static IRImportManager *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IRImportManager alloc] init];
    });
    return instancia;
}

- (void)importFileAtPath:(NSString *)path
                completion:(void (^)(IRDocument *document, NSError *error))completion {
    [self importFileAtPath:path move:NO completion:completion];
}

- (void)importFileAtPath:(NSString *)path
                    move:(BOOL)move
              completion:(void (^)(IRDocument *document, NSError *error))completion {
    if (!path.length) {
        [self terminar:completion documento:nil error:IRImportError(@"Ruta vacía")];
        return;
    }
    NSString *origen = [path stringByStandardizingPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL esDir = NO;
    if (![fm fileExistsAtPath:origen isDirectory:&esDir] || esDir) {
        [self terminar:completion documento:nil error:IRImportError(@"El archivo no existe")];
        return;
    }

    IRDocument *existente = [[IRLibrary shared] documentWithPath:origen];
    if (existente) {
        existente.lastOpenedAt = [NSDate date];
        [[IRLibrary shared] save];
        [self terminar:completion documento:existente error:nil];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *destino = origen;
        NSString *importados = [IRUtils importedPath];
        BOOL yaImportado = [[origen stringByStandardizingPath] hasPrefix:[importados stringByStandardizingPath]];
        BOOL dentroDeDocumentos = [[origen stringByStandardizingPath] hasPrefix:[[IRUtils documentsPath] stringByStandardizingPath]];
        NSError *error = nil;

        if (!yaImportado) {
            NSString *nombre = [origen lastPathComponent];
            destino = [IRUtils uniquePathForName:nombre inDirectory:importados];
            if (move || dentroDeDocumentos) {
                if (![fm moveItemAtPath:origen toPath:destino error:&error]) {
                    destino = origen;
                    error = nil;
                }
            } else {
                if (![fm copyItemAtPath:origen toPath:destino error:&error]) {
                    destino = origen;
                    error = nil;
                }
            }
        }

        NSDictionary *attrs = [fm attributesOfItemAtPath:destino error:NULL];
        IRDocument *doc = [[IRDocument alloc] init];
        doc.path = destino;
        doc.title = [[destino lastPathComponent] stringByDeletingPathExtension];
        doc.author = @"";
        doc.type = [IRUtils typeForPath:destino];
        doc.fileSize = [attrs[NSFileSize] unsignedLongLongValue];
        doc.addedAt = [NSDate date];
        doc.lastOpenedAt = [NSDate date];
        doc.coverSeed = (NSUInteger)([[IRUtils sha1OfString:destino] hash] % 997);

        dispatch_async(dispatch_get_main_queue(), ^{
            [[IRLibrary shared] addDocument:doc];
            if (completion) completion(doc, nil);
            [self extraerMetadatosDe:doc];
        });
    });
}

- (void)importData:(NSData *)data
          fileName:(NSString *)fileName
        completion:(void (^)(IRDocument *document, NSError *error))completion {
    if (!data.length || !fileName.length) {
        [self terminar:completion documento:nil error:IRImportError(@"Archivo vacío")];
        return;
    }
    NSString *nombre = [fileName lastPathComponent];
    NSString *destino = [IRUtils uniquePathForName:nombre inDirectory:[IRUtils importedPath]];
    if (![data writeToFile:destino options:NSDataWritingAtomic error:NULL]) {
        [self terminar:completion documento:nil error:IRImportError(@"No se pudo guardar el archivo")];
        return;
    }
    [self importFileAtPath:destino move:NO completion:completion];
}

- (void)refreshMetadataForDocument:(IRDocument *)document {
    if (!document) return;
    [self extraerMetadatosDe:document];
}

- (void)extraerMetadatosDe:(IRDocument *)doc {
    if (!doc) return;
    [IRMetadata loadMetadataForDocument:doc completion:^(UIImage *cover) {
        if (cover) {
            [[IRLibrary shared] saveCoverImage:cover forDocument:doc];
        }
        [[IRLibrary shared] save];
        [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification
                                                            object:[IRLibrary shared]];
    }];
}

- (void)terminar:(void (^)(IRDocument *, NSError *))completion
       documento:(IRDocument *)doc
           error:(NSError *)error {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(doc, error);
    });
}

@end
