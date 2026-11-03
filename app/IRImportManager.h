#import <Foundation/Foundation.h>
#import "IRModels.h"

extern NSString * const IRImportErrorDomain;

@interface IRImportManager : NSObject

+ (instancetype)shared;

// Copia (o mueve) el archivo a la carpeta de importados, lo registra en la
// biblioteca y extrae metadatos/portada en segundo plano.
- (void)importFileAtPath:(NSString *)path
                completion:(void (^)(IRDocument *document, NSError *error))completion;

- (void)importFileAtPath:(NSString *)path
                    move:(BOOL)move
              completion:(void (^)(IRDocument *document, NSError *error))completion;

- (void)importData:(NSData *)data
          fileName:(NSString *)fileName
        completion:(void (^)(IRDocument *document, NSError *error))completion;

// Vuelve a extraer portada y metadatos (por ejemplo tras editar el titulo).
- (void)refreshMetadataForDocument:(IRDocument *)document;

@end
