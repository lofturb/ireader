#import "IRArchive.h"
#import <zlib.h>
#import <string.h>

NSString * const IRArchiveErrorDomain = @"IRArchiveErrorDomain";

#define IRZIP_EOCD 0x06054b50
#define IRZIP_CENTRAL 0x02014b50
#define IRZIP_LOCAL 0x04034b50

static NSError *IRZipError(NSString *mensaje) {
    return [NSError errorWithDomain:IRArchiveErrorDomain code:1
                           userInfo:@{NSLocalizedDescriptionKey: mensaje ?: @"Error de ZIP"}];
}

static uint16_t irLe16(const uint8_t *p) {
    return (uint16_t)(p[0] | (p[1] << 8));
}
static uint32_t irLe32(const uint8_t *p) {
    return (uint32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24));
}

@interface IRArchive ()
+ (NSData *)dataForEntryInfo:(NSDictionary *)entry atPath:(NSString *)zipPath error:(NSError **)error;
@end

@implementation IRArchive

+ (BOOL)isZipAtPath:(NSString *)path {
    NSFileHandle *h = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!h) return NO;
    NSData *d = [h readDataOfLength:4];
    [h closeFile];
    if (d.length < 4) return NO;
    const uint8_t *b = d.bytes;
    return (b[0] == 'P' && b[1] == 'K' &&
            ((b[2] == 3 && b[3] == 4) || (b[2] == 5 && b[3] == 6) || (b[2] == 7 && b[3] == 8)));
}

+ (NSArray<NSDictionary *> *)listEntriesAtPath:(NSString *)zipPath
                                         error:(NSError **)error {
    NSFileHandle *h = [NSFileHandle fileHandleForReadingAtPath:zipPath];
    if (!h) {
        if (error) *error = IRZipError(@"No se pudo abrir el archivo ZIP");
        return nil;
    }
    unsigned long long tam = [h seekToEndOfFile];
    if (tam < 22) {
        [h closeFile];
        if (error) *error = IRZipError(@"El ZIP está vacío o incompleto");
        return nil;
    }
    unsigned long long ventana = MIN(tam, (unsigned long long)65557);
    [h seekToFileOffset:tam - ventana];
    NSData *cola = [h readDataOfLength:(NSUInteger)ventana];
    const uint8_t *cb = cola.bytes;
    NSInteger pos = (NSInteger)cola.length - 22;
    NSInteger eocd = -1;
    while (pos >= 0) {
        if (pos + 4 <= (NSInteger)cola.length && irLe32(cb + pos) == IRZIP_EOCD) {
            eocd = pos;
            break;
        }
        pos--;
    }
    if (eocd < 0) {
        [h closeFile];
        if (error) *error = IRZipError(@"No es un ZIP válido");
        return nil;
    }
    uint16_t total = irLe16(cb + eocd + 10);
    uint32_t cdOffset = irLe32(cb + eocd + 16);
    if (total == 0xFFFF || cdOffset == 0xFFFFFFFF) {
        [h closeFile];
        if (error) *error = IRZipError(@"ZIP64 no soportado");
        return nil;
    }

    [h seekToFileOffset:cdOffset];
    NSMutableArray *salida = [NSMutableArray arrayWithCapacity:total];
    for (uint16_t i = 0; i < total; i++) {
        NSData *cab = [h readDataOfLength:46];
        if (cab.length < 46) break;
        const uint8_t *c = cab.bytes;
        if (irLe32(c) != IRZIP_CENTRAL) break;
        uint16_t flags = irLe16(c + 8);
        uint16_t method = irLe16(c + 10);
        uint32_t crc = irLe32(c + 16);
        uint32_t comp = irLe32(c + 20);
        uint32_t uncomp = irLe32(c + 24);
        uint16_t nameLen = irLe16(c + 28);
        uint16_t extraLen = irLe16(c + 30);
        uint16_t commentLen = irLe16(c + 32);
        uint32_t localOffset = irLe32(c + 42);
        NSData *nombreDatos = [h readDataOfLength:nameLen];
        NSString *nombre = nil;
        if (flags & 0x0800) {
            nombre = [[NSString alloc] initWithData:nombreDatos encoding:NSUTF8StringEncoding];
        } else {
            nombre = [[NSString alloc] initWithData:nombreDatos encoding:NSUTF8StringEncoding];
            if (!nombre) nombre = [[NSString alloc] initWithData:nombreDatos encoding:NSISOLatin1StringEncoding];
        }
        if (extraLen) [h seekToFileOffset:[h offsetInFile] + extraLen];
        if (commentLen) [h seekToFileOffset:[h offsetInFile] + commentLen];
        if (!nombre) nombre = @"";
        BOOL dir = [nombre hasSuffix:@"/"];
        [salida addObject:@{
            @"name": nombre,
            @"size": @(uncomp),
            @"compressedSize": @(comp),
            @"crc": @(crc),
            @"method": @(method),
            @"isDirectory": @(dir),
            @"localOffset": @(localOffset)
        }];
    }
    [h closeFile];
    return salida;
}

+ (NSData *)dataForEntry:(NSString *)entryName
                  atPath:(NSString *)zipPath
                   error:(NSError **)error {
    NSArray *entradas = [self listEntriesAtPath:zipPath error:error];
    if (!entradas) return nil;
    NSDictionary *elegida = nil;
    for (NSDictionary *e in entradas) {
        if ([e[@"name"] isEqualToString:entryName]) { elegida = e; break; }
    }
    if (!elegida) {
        if (error) *error = IRZipError(@"La entrada no existe dentro del ZIP");
        return nil;
    }
    return [self dataForEntryInfo:elegida atPath:zipPath error:error];
}

+ (NSData *)dataForEntryInfo:(NSDictionary *)elegida
                      atPath:(NSString *)zipPath
                       error:(NSError **)error {
    uint16_t method = (uint16_t)[elegida[@"method"] unsignedIntegerValue];
    uint32_t comp = (uint32_t)[elegida[@"compressedSize"] unsignedIntegerValue];
    uint32_t uncomp = (uint32_t)[elegida[@"size"] unsignedIntegerValue];
    uint32_t localOffset = (uint32_t)[elegida[@"localOffset"] unsignedIntegerValue];

    NSFileHandle *h = [NSFileHandle fileHandleForReadingAtPath:zipPath];
    if (!h) {
        if (error) *error = IRZipError(@"No se pudo abrir el ZIP");
        return nil;
    }
    [h seekToFileOffset:localOffset];
    NSData *local = [h readDataOfLength:30];
    if (local.length < 30 || irLe32(local.bytes) != IRZIP_LOCAL) {
        [h closeFile];
        if (error) *error = IRZipError(@"Cabecera local del ZIP dañada");
        return nil;
    }
    const uint8_t *l = local.bytes;
    uint16_t lName = irLe16(l + 26);
    uint16_t lExtra = irLe16(l + 28);
    unsigned long long dataOffset = (unsigned long long)localOffset + 30 + lName + lExtra;
    [h seekToFileOffset:dataOffset];
    NSData *comprimido = [h readDataOfLength:comp];
    [h closeFile];
    if (!comprimido) {
        if (error) *error = IRZipError(@"No se pudieron leer los datos del ZIP");
        return nil;
    }
    if (method == 0) {
        return comprimido;
    }
    if (method != 8) {
        if (error) *error = IRZipError(@"Método de compresión no soportado");
        return nil;
    }
    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (inflateInit2(&zs, -15) != Z_OK) {
        if (error) *error = IRZipError(@"No se pudo iniciar zlib");
        return nil;
    }
    zs.next_in = (Bytef *)comprimido.bytes;
    zs.avail_in = (uInt)comprimido.length;
    NSMutableData *salida = [NSMutableData dataWithCapacity:uncomp ? uncomp : comp * 2];
    uint8_t buf[65536];
    int ret = Z_OK;
    while (ret != Z_STREAM_END) {
        zs.next_out = buf;
        zs.avail_out = (uInt)sizeof(buf);
        ret = inflate(&zs, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
            inflateEnd(&zs);
            if (error) *error = IRZipError(@"Datos comprimidos dañados");
            return nil;
        }
        size_t hay = sizeof(buf) - zs.avail_out;
        if (hay) [salida appendBytes:buf length:hay];
        if (ret == Z_BUF_ERROR && zs.avail_in == 0) break;
    }
    inflateEnd(&zs);
    return salida;
}

+ (BOOL)extractArchive:(NSString *)zipPath
           toDirectory:(NSString *)destDir
              progress:(IRArchiveProgress)progress
                cancel:(IRArchiveCancel)cancel
                 error:(NSError **)error {
    NSArray *entradas = [self listEntriesAtPath:zipPath error:error];
    if (!entradas) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:destDir]) {
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *base = [destDir stringByStandardizingPath];
    NSUInteger total = entradas.count;
    NSUInteger hechos = 0;
    for (NSDictionary *e in entradas) {
        if (cancel && cancel()) {
            if (error) *error = IRZipError(@"Cancelado");
            return NO;
        }
        NSString *nombre = e[@"name"];
        if (!nombre.length || [nombre hasPrefix:@"/"] || [nombre rangeOfString:@".."].location != NSNotFound) {
            hechos++;
            continue;
        }
        NSString *ruta = [[destDir stringByAppendingPathComponent:nombre] stringByStandardizingPath];
        if (![ruta hasPrefix:base]) {
            hechos++;
            continue;
        }
        if ([e[@"isDirectory"] boolValue]) {
            [fm createDirectoryAtPath:ruta withIntermediateDirectories:YES attributes:nil error:NULL];
        } else {
            [fm createDirectoryAtPath:[ruta stringByDeletingLastPathComponent]
          withIntermediateDirectories:YES attributes:nil error:NULL];
            NSData *datos = [self dataForEntryInfo:e atPath:zipPath error:error];
            if (!datos) return NO;
            if (![datos writeToFile:ruta options:NSDataWritingAtomic error:error]) return NO;
        }
        hechos++;
        if (progress) progress((double)hechos / (double)MAX(1, total), nombre);
    }
    return YES;
}

@end
