#import "IRHTTPServer.h"
#import "IRUtils.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <unistd.h>
#import <fcntl.h>
#import <string.h>
#import <errno.h>
#import <sys/select.h>
#import <sys/time.h>
#import <stdlib.h>

// Servidor HTTP minimo para recibir archivos desde el ordenador por Wi-Fi.
// Escucha en un socket TCP y atiende una conexion cada vez en su propio hilo.
// Soporta:
//   GET  /                 pagina de subida con la lista de archivos recibidos
//   GET  /api/list         listado JSON
//   GET  /download/<n>     descarga del archivo numero <n>
//   POST /upload           multipart/form-data (formularios y curl -F)
//   POST /upload?name=foo  cuerpo binario con nombre indicado
//   PUT  /upload/foo.pdf   cuerpo binario directo
//   DELETE /file/<nombre>  borra un archivo subido
// Respuestas siempre con cabeceras CORS para que puedan usarse desde script.

static const NSUInteger IRMaxCabecera = 96 * 1024;
static const NSUInteger IRMaxSubida = 1024ull * 1024ull * 1024ull;   // 1 GB

static NSString *IRFileSafeName(NSString *nombre) {
    NSString *base = [nombre lastPathComponent];
    NSMutableString *salida = [NSMutableString string];
    NSData *datos = [base dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
    const uint8_t *bytes = datos.bytes;
    for (NSUInteger i = 0; i < datos.length && salida.length < 200; i++) {
        uint8_t c = bytes[i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
            c == '.' || c == '-' || c == '_' || c == ' ' || c == '(' || c == ')') {
            [salida appendFormat:@"%c", c];
        } else {
            [salida appendString:@"_"];
        }
    }
    NSString *limpio = [salida stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!limpio.length || [limpio isEqualToString:@"."] || [limpio isEqualToString:@".."]) {
        limpio = [NSString stringWithFormat:@"archivo-%ld", (long)[[NSDate date] timeIntervalSince1970]];
    }
    return limpio;
}

static NSString *IRUniquePath(NSString *directorio, NSString *nombre) {
    NSString *destino = [directorio stringByAppendingPathComponent:nombre];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destino]) return destino;
    NSString *base = [nombre stringByDeletingPathExtension];
    NSString *ext = [nombre pathExtension];
    for (int i = 2; i < 9999; i++) {
        NSString *nuevo = ext.length ? [NSString stringWithFormat:@"%@ %d.%@", base, i, ext]
                                     : [NSString stringWithFormat:@"%@ %d", base, i];
        destino = [directorio stringByAppendingPathComponent:nuevo];
        if (![[NSFileManager defaultManager] fileExistsAtPath:destino]) return destino;
    }
    return [directorio stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
}

static NSString *IRReason(int codigo) {
    switch (codigo) {
        case 200: return @"OK";
        case 201: return @"Created";
        case 204: return @"No Content";
        case 400: return @"Bad Request";
        case 404: return @"Not Found";
        case 405: return @"Method Not Allowed";
        case 413: return @"Payload Too Large";
        default: return @"OK";
    }
}

@interface IRHTTPServer ()
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) int listenFD;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) BOOL stopRequested;
@property (nonatomic, copy) NSString *serverName;
@end

@implementation IRHTTPServer

+ (instancetype)shared {
    static IRHTTPServer *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IRHTTPServer alloc] init];
        instancia.listenFD = -1;
        instancia.serverName = @"IReader";
    });
    return instancia;
}

- (NSString *)uploadsDirectory {
    if (!_uploadsDirectory.length) {
        _uploadsDirectory = [IRUtils uploadsPath];
    }
    return _uploadsDirectory;
}

#pragma mark - Arranque y parada

- (BOOL)startOnPort:(NSInteger)puerto uploadsDirectory:(NSString *)directorio {
    [self stop];
    if (puerto < 1024 || puerto > 65535) puerto = 8080;
    if (directorio.length) self.uploadsDirectory = directorio;
    [[NSFileManager defaultManager] createDirectoryAtPath:self.uploadsDirectory
                             withIntermediateDirectories:YES attributes:nil error:NULL];

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return NO;

    int uno = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &uno, sizeof(uno));

    struct sockaddr_in direccion;
    memset(&direccion, 0, sizeof(direccion));
    direccion.sin_len = sizeof(direccion);
    direccion.sin_family = AF_INET;
    direccion.sin_port = htons((uint16_t)puerto);
    direccion.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(fd, (struct sockaddr *)&direccion, sizeof(direccion)) < 0) {
        close(fd);
        return NO;
    }
    if (listen(fd, 8) < 0) {
        close(fd);
        return NO;
    }

    int noSig = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSig, sizeof(noSig));

    self.listenFD = fd;
    self.port = puerto;
    self.stopRequested = NO;
    self.running = YES;
    self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoop) object:nil];
    self.thread.name = @"IReaderHTTPServer";
    [self.thread start];
    return YES;
}

- (void)stop {
    self.stopRequested = YES;
    self.running = NO;
    if (self.listenFD >= 0) {
        close(self.listenFD);
        self.listenFD = -1;
    }
}

- (void)runLoop {
    @autoreleasepool {
        while (!self.stopRequested) {
            int escucha = self.listenFD;
            if (escucha < 0) break;
            fd_set lectura;
            FD_ZERO(&lectura);
            FD_SET(escucha, &lectura);
            struct timeval espera;
            espera.tv_sec = 1;
            espera.tv_usec = 0;
            int listo = select(escucha + 1, &lectura, NULL, NULL, &espera);
            if (listo <= 0) continue;

            struct sockaddr_in cliente;
            socklen_t longitud = sizeof(cliente);
            int cfd = accept(escucha, (struct sockaddr *)&cliente, &longitud);
            if (cfd < 0) continue;

            [self atenderCliente:cfd];
            close(cfd);
        }
    }
}

#pragma mark - Red

- (void)atenderCliente:(int)cfd {
    struct timeval tiempo;
    tiempo.tv_sec = 30;
    tiempo.tv_usec = 0;
    setsockopt(cfd, SOL_SOCKET, SO_RCVTIMEO, &tiempo, sizeof(tiempo));
    setsockopt(cfd, SOL_SOCKET, SO_SNDTIMEO, &tiempo, sizeof(tiempo));
    int uno = 1;
    setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &uno, sizeof(uno));
    setsockopt(cfd, SOL_SOCKET, SO_NOSIGPIPE, &uno, sizeof(uno));

    NSMutableData *buffer = [NSMutableData data];
    NSInteger finCabecera = [self leerHastaCabecera:cfd buffer:buffer];
    if (finCabecera < 0) return;

    NSData *datosCabecera = [buffer subdataWithRange:NSMakeRange(0, (NSUInteger)finCabecera)];
    NSString *cabecera = [[NSString alloc] initWithData:datosCabecera encoding:NSISOLatin1StringEncoding];
    if (!cabecera.length) return;

    NSArray *lineas = [cabecera componentsSeparatedByString:@"\r\n"];
    if (lineas.count == 0) return;
    NSArray *peticion = [lineas[0] componentsSeparatedByString:@" "];
    if (peticion.count < 2) {
        [self responder:cfd codigo:400 tipo:@"text/plain" cuerpo:[@"Solicitud no válida" dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }
    NSString *metodo = [peticion[0] uppercaseString];
    NSString *ruta = peticion[1];

    NSMutableDictionary *campos = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lineas.count; i++) {
        NSRange dos = [lineas[i] rangeOfString:@":"];
        if (dos.location == NSNotFound) continue;
        NSString *clave = [[lineas[i] substringToIndex:dos.location] lowercaseString];
        NSString *valor = [[lineas[i] substringFromIndex:dos.location + 1]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (clave.length) campos[clave] = valor;
    }

    if ([metodo isEqualToString:@"OPTIONS"]) {
        [self responder:cfd codigo:204 tipo:@"text/plain" cuerpo:nil];
        return;
    }

    if ([metodo isEqualToString:@"GET"] || [metodo isEqualToString:@"HEAD"]) {
        [self atenderGET:cfd ruta:ruta soloCabecera:[metodo isEqualToString:@"HEAD"]];
        return;
    }

    if ([metodo isEqualToString:@"PUT"]) {
        NSData *cuerpo = [self leerCuerpo:cfd buffer:buffer campos:campos];
        if (!cuerpo) {
            [self responder:cfd codigo:400 tipo:@"text/plain" cuerpo:[@"Error de lectura" dataUsingEncoding:NSUTF8StringEncoding]];
            return;
        }
        NSString *nombre = [[ruta lastPathComponent] stringByRemovingPercentEncoding];
        if (!nombre.length) nombre = [IRFileSafeName:@"subida"];
        [self guardarCuerpo:cuerpo nombre:nombre cfd:cfd];
        return;
    }

    if ([metodo isEqualToString:@"POST"]) {
        NSData *cuerpo = [self leerCuerpo:cfd buffer:buffer campos:campos];
        if (!cuerpo) {
            [self responder:cfd codigo:400 tipo:@"text/plain" cuerpo:[@"Error de lectura" dataUsingEncoding:NSUTF8StringEncoding]];
            return;
        }
        NSRange interrogacion = [ruta rangeOfString:@"?"];
        NSString *nombreConsulta = nil;
        if (interrogacion.location != NSNotFound) {
            NSString *consulta = [ruta substringFromIndex:NSMaxRange(interrogacion)];
            for (NSString *par in [consulta componentsSeparatedByString:@"&"]) {
                NSRange igual = [par rangeOfString:@"="];
                if (igual.location == NSNotFound) continue;
                NSString *clave = [par substringToIndex:igual.location];
                if ([clave isEqualToString:@"name"] || [clave isEqualToString:@"filename"]) {
                    nombreConsulta = [[par substringFromIndex:NSMaxRange(igual)] stringByRemovingPercentEncoding];
                }
            }
            ruta = [ruta substringToIndex:interrogacion.location];
        }
        if ([ruta hasPrefix:@"/upload"]) {
            NSString *tipoContenido = campos[@"content-type"] ?: @"";
            if ([tipoContenido rangeOfString:@"multipart/form-data" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                NSInteger guardados = [self guardarMultipart:cuerpo tipo:tipoContenido];
                [self responderJSON:cfd ok:YES mensaje:(guardados > 0 ? @"Recibido" : @"Sin archivos")];
            } else {
                NSString *nombre = nombreConsulta.length ? nombreConsulta : [IRFileSafeName:@"subida"];
                [self guardarCuerpo:cuerpo nombre:nombre cfd:cfd];
            }
            return;
        }
        [self responder:cfd codigo:404 tipo:@"text/plain" cuerpo:[@"No encontrado" dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }

    if ([metodo isEqualToString:@"DELETE"]) {
        NSString *nombre = [[ruta lastPathComponent] stringByRemovingPercentEncoding];
        BOOL borrado = [self borrarArchivo:nombre];
        [self responderJSON:cfd ok:borrado mensaje:borrado ? @"Eliminado" : @"No existe"];
        return;
    }

    [self responder:cfd codigo:405 tipo:@"text/plain" cuerpo:[@"Método no soportado" dataUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark - Lectura

- (NSInteger)leerHastaCabecera:(int)cfd buffer:(NSMutableData *)buffer {
    const char *fin = "\r\n\r\n";
    size_t finLen = 4;
    while (buffer.length < IRMaxCabecera) {
        uint8_t temporal[8192];
        ssize_t n = recv(cfd, temporal, sizeof(temporal), 0);
        if (n > 0) {
            [buffer appendBytes:temporal length:(NSUInteger)n];
            const uint8_t *bytes = buffer.bytes;
            if (buffer.length >= finLen) {
                for (NSInteger i = (NSInteger)buffer.length - (NSInteger)finLen; i >= 0; i--) {
                    if (memcmp(bytes + i, fin, finLen) == 0) {
                        return i + (NSInteger)finLen;
                    }
                }
            }
        } else if (n == 0) {
            return buffer.length >= finLen ? 0 : -1;
        } else {
            if (errno == EINTR) continue;
            return -1;
        }
    }
    return -1;
}

- (NSData *)leerCuerpo:(int)cfd buffer:(NSMutableData *)buffer campos:(NSDictionary *)campos {
    NSInteger finCabecera = [self buscarFinCabecera:buffer];
    if (finCabecera < 0) return nil;
    NSUInteger yaLeido = buffer.length - (NSUInteger)finCabecera;
    unsigned long long longitud = 0;
    NSString *largo = campos[@"content-length"];
    if (largo.length) longitud = strtoull(largo.UTF8String, NULL, 10);
    if (longitud > IRMaxSubida) return nil;

    if (yaLeido < longitud) {
        NSMutableData *total = [[buffer subdataWithRange:NSMakeRange((NSUInteger)finCabecera, yaLeido)] mutableCopy];
        while (total.length < longitud) {
            uint8_t temporal[65536];
            NSUInteger pedir = (NSUInteger)MIN((unsigned long long)sizeof(temporal),
                                               (unsigned long long)(longitud - total.length));
            if (pedir == 0) break;
            ssize_t n = recv(cfd, temporal, pedir, 0);
            if (n > 0) {
                [total appendBytes:temporal length:(NSUInteger)n];
            } else if (n == 0) {
                break;
            } else if (errno == EINTR) {
                continue;
            } else {
                break;
            }
        }
        return [total copy];
    }
    if ((NSUInteger)longitud <= buffer.length - (NSUInteger)finCabecera) {
        return [buffer subdataWithRange:NSMakeRange((NSUInteger)finCabecera, (NSUInteger)longitud)];
    }
    NSUInteger disponible = buffer.length - (NSUInteger)finCabecera;
    return [buffer subdataWithRange:NSMakeRange((NSUInteger)finCabecera, disponible)];
}

- (NSInteger)buscarFinCabecera:(NSData *)datos {
    const char *fin = "\r\n\r\n";
    const uint8_t *bytes = datos.bytes;
    if (datos.length < 4) return -1;
    for (NSInteger i = (NSInteger)datos.length - 4; i >= 0; i--) {
        if (memcmp(bytes + i, fin, 4) == 0) return i + 4;
    }
    return -1;
}

#pragma mark - Guardado

- (void)guardarCuerpo:(NSData *)cuerpo nombre:(NSString *)nombre cfd:(int)cfd {
    NSString *limpio = IRFileSafeName(nombre);
    NSString *destino = IRUniquePath(self.uploadsDirectory, limpio);
    if ([cuerpo writeToFile:destino options:NSDataWritingAtomic error:NULL]) {
        [self avisarSubida:destino];
        [self responderJSON:cfd ok:YES mensaje:[NSString stringWithFormat:@"Guardado como %@", destino.lastPathComponent]];
    } else {
        [self responder:cfd codigo:500 tipo:@"text/plain" cuerpo:[@"No se pudo guardar" dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (NSInteger)guardarMultipart:(NSData *)cuerpo tipo:(NSString *)tipo {
    NSString *frontera = nil;
    NSRange marca = [tipo rangeOfString:@"boundary=" options:NSCaseInsensitiveSearch];
    if (marca.location != NSNotFound) {
        frontera = [tipo substringFromIndex:NSMaxRange(marca)];
        if ([frontera hasPrefix:@"\""]) {
            frontera = [frontera substringFromIndex:1];
            NSRange cierre = [frontera rangeOfString:@"\""];
            if (cierre.location != NSNotFound) frontera = [frontera substringToIndex:cierre.location];
        }
    }
    if (!frontera.length) return 0;

    NSData *marcaDatos = [[NSString stringWithFormat:@"--%@", frontera] dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = cuerpo.bytes;
    NSUInteger longitud = cuerpo.length;
    NSUInteger inicio = 0;
    NSInteger guardados = 0;

    while (inicio < longitud) {
        NSRange rangoMarca = [cuerpo rangeOfData:marcaDatos options:0
                                           range:NSMakeRange(inicio, longitud - inicio)];
        if (rangoMarca.location == NSNotFound) break;
        NSUInteger despuesMarca = NSMaxRange(rangoMarca);
        if (despuesMarca + 2 > longitud) break;
        NSUInteger inicioParte = despuesMarca;
        if (bytes[inicioParte] == '\r' && bytes[inicioParte + 1] == '\n') {
            inicioParte += 2;
        }
        NSRange siguente = [cuerpo rangeOfData:marcaDatos options:0
                                         range:NSMakeRange(inicioParte, longitud - inicioParte)];
        if (siguente.location == NSNotFound) break;
        NSUInteger finParte = siguente.location;
        if (finParte >= 2 && bytes[finParte - 2] == '\r' && bytes[finParte - 1] == '\n') {
            finParte -= 2;
        }

        NSData *parte = [cuerpo subdataWithRange:NSMakeRange(inicioParte, finParte - inicioParte)];
        NSInteger finCabecera = [self buscarFinCabecera:parte];
        if (finCabecera > 0) {
            NSData *datosCabecera = [parte subdataWithRange:NSMakeRange(0, (NSUInteger)finCabecera)];
            NSString *cabecera = [[NSString alloc] initWithData:datosCabecera encoding:NSISOLatin1StringEncoding];
            NSString *nombre = nil;
            NSRange disp = [cabecera rangeOfString:@"filename=" options:NSCaseInsensitiveSearch];
            if (disp.location != NSNotFound) {
                NSString *resto = [cabecera substringFromIndex:NSMaxRange(disp)];
                if ([resto hasPrefix:@"\""]) {
                    resto = [resto substringFromIndex:1];
                    NSRange cierre = [resto rangeOfString:@"\""];
                    if (cierre.location != NSNotFound) nombre = [resto substringToIndex:cierre.location];
                } else {
                    NSRange finLinea = [resto rangeOfString:@"\r"];
                    if (finLinea.location == NSNotFound) finLinea = [resto rangeOfString:@"\n"];
                    nombre = (finLinea.location != NSNotFound) ? [resto substringToIndex:finLinea.location] : resto;
                }
            }
            NSData *datos = [parte subdataWithRange:NSMakeRange((NSUInteger)finCabecera, parte.length - (NSUInteger)finCabecera)];
            if (nombre.length && datos.length) {
                NSString *limpio = IRFileSafeName(nombre);
                NSString *destino = IRUniquePath(self.uploadsDirectory, limpio);
                if ([datos writeToFile:destino options:NSDataWritingAtomic error:NULL]) {
                    [self avisarSubida:destino];
                    guardados++;
                }
            }
        }
        inicio = NSMaxRange(siguente);
    }
    return guardados;
}

- (BOOL)borrarArchivo:(NSString *)nombre {
    if (!nombre.length) return NO;
    NSString *destino = [self.uploadsDirectory stringByAppendingPathComponent:IRFileSafeName(nombre)];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destino]) {
        return [[NSFileManager defaultManager] removeItemAtPath:destino error:NULL];
    }
    return NO;
}

- (void)avisarSubida:(NSString *)ruta {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onFileUploaded) self.onFileUploaded(ruta);
    });
}

#pragma mark - Respuestas

- (void)responder:(int)cfd codigo:(int)codigo tipo:(NSString *)tipo cuerpo:(NSData *)cuerpo {
    NSMutableString *cabecera = [NSMutableString string];
    [cabecera appendFormat:@"HTTP/1.1 %d %@\r\n", codigo, IRReason(codigo)];
    [cabecera appendFormat:@"Content-Type: %@\r\n", tipo ?: @"text/plain; charset=utf-8"];
    [cabecera appendFormat:@"Content-Length: %lu\r\n", (unsigned long)cuerpo.length];
    [cabecera appendString:@"Connection: close\r\n"];
    [cabecera appendString:@"Access-Control-Allow-Origin: *\r\n"];
    [cabecera appendString:@"Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"];
    [cabecera appendString:@"Access-Control-Allow-Headers: Content-Type\r\n"];
    [cabecera appendString:@"Cache-Control: no-store\r\n\r\n"];
    NSMutableData *salida = [[cabecera dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    if (cuerpo.length) [salida appendData:cuerpo];
    const uint8_t *bytes = salida.bytes;
    size_t total = salida.length;
    size_t enviado = 0;
    while (enviado < total) {
        ssize_t n = send(cfd, bytes + enviado, total - enviado, 0);
        if (n > 0) {
            enviado += (size_t)n;
        } else if (n < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
}

- (void)responderJSON:(int)cfd ok:(BOOL)ok mensaje:(NSString *)mensaje {
    NSDictionary *respuesta = @{@"ok": @(ok), @"message": mensaje ?: @""};
    NSData *datos = [NSJSONSerialization dataWithJSONObject:respuesta options:0 error:NULL];
    [self responder:cfd codigo:(ok ? 200 : 400) tipo:@"application/json; charset=utf-8" cuerpo:datos];
}

- (void)atenderGET:(int)cfd ruta:(NSString *)ruta soloCabecera:(BOOL)head {
    NSString *camino = ruta;
    NSRange interrogacion = [camino rangeOfString:@"?"];
    if (interrogacion.location != NSNotFound) camino = [camino substringToIndex:interrogacion.location];

    if ([camino isEqualToString:@"/api/list"]) {
        NSData *datos = [NSJSONSerialization dataWithJSONObject:[self listado] options:0 error:NULL];
        [self responder:cfd codigo:200 tipo:@"application/json; charset=utf-8" cuerpo:datos];
        return;
    }

    if ([camino hasPrefix:@"/download/"]) {
        NSString *nombre = [[camino substringFromIndex:10] stringByRemovingPercentEncoding];
        NSString *destino = [self.uploadsDirectory stringByAppendingPathComponent:IRFileSafeName(nombre)];
        NSData *datos = [NSData dataWithContentsOfFile:destino];
        if (datos) {
            [self responder:cfd codigo:200 tipo:@"application/octet-stream" cuerpo:(head ? nil : datos)];
        } else {
            [self responder:cfd codigo:404 tipo:@"text/plain" cuerpo:[@"No encontrado" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        return;
    }

    if ([camino isEqualToString:@"/"] || [camino isEqualToString:@"/index.html"]) {
        NSData *pagina = [[self paginaSubida] dataUsingEncoding:NSUTF8StringEncoding];
        [self responder:cfd codigo:200 tipo:@"text/html; charset=utf-8" cuerpo:(head ? nil : pagina)];
        return;
    }

    [self responder:cfd codigo:404 tipo:@"text/plain" cuerpo:[@"No encontrado" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSArray *)listado {
    NSFileManager *gestor = [NSFileManager defaultManager];
    NSArray *contenido = [gestor contentsOfDirectoryAtPath:self.uploadsDirectory error:NULL];
    NSMutableArray *salida = [NSMutableArray array];
    for (NSString *nombre in contenido) {
        if ([nombre hasPrefix:@"."]) continue;
        NSString *ruta = [self.uploadsDirectory stringByAppendingPathComponent:nombre];
        NSDictionary *atributos = [gestor attributesOfItemAtPath:ruta error:NULL];
        [salida addObject:@{
            @"name": nombre,
            @"size": atributos[NSFileSize] ?: @0,
            @"date": @([[atributos[NSFileModificationDate] ?: [NSDate date] timeIntervalSince1970] doubleValue])
        }];
    }
    return salida;
}

- (NSString *)paginaSubida {
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"];
    [html appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"];
    [html appendString:@"<title>IReader · Subir archivos</title><style>"];
    [html appendString:@"*{box-sizing:border-box;} body{margin:0;background:#F6F1E7;color:#231F1A;"];
    [html appendString:@"font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;padding:28px 22px;}"];
    [html appendString:@"h1{font-family:Georgia,serif;font-size:30px;margin:0 0 6px;}"];
    [html appendString:@"p.sub{color:#6E665A;margin:0 0 22px;}"];
    [html appendString:@".drop{border:2px dashed #C9B79C;border-radius:16px;background:#FFFCF6;"];
    [html appendString:@"padding:36px 22px;text-align:center;transition:.2s;}"];
    [html appendString:@".drop.on{border-color:#B4552F;background:#FBEFE6;}"];
    [html appendString:@".drop strong{color:#B4552F;}"];
    [html appendString:@"input[type=file]{display:none;}"];
    [html appendString:@".btn{display:inline-block;margin-top:14px;background:#B4552F;color:#fff;"];
    [html appendString:@"padding:11px 22px;border-radius:10px;cursor:pointer;font-weight:600;}"];
    [html appendString:@"ul{list-style:none;padding:0;margin:24px 0 0;} li{background:#FFFCF6;border:1px solid #E0D6C4;"];
    [html appendString:@"border-radius:10px;padding:12px 14px;margin-bottom:8px;display:flex;justify-content:space-between;}"];
    [html appendString:@"li .t{font-size:13px;color:#6E665A;} a{color:#B4552F;text-decoration:none;font-size:13px;}"];
    [html appendString:@"#log{margin-top:14px;font-size:13px;color:#4E8C5A;min-height:18px;}"];
    [html appendString:@"</style></head><body>"];
    [html appendString:@"<h1>IReader</h1><p class=\"sub\">Arrastra archivos o pulsa para subirlos al iPad.</p>"];
    [html appendString:@"<div class=\"drop\" id=\"drop\"><strong>Pulsa aquí</strong> o arrastra tus documentos<br>"];
    [html appendString:@"<span class=\"t\">PDF, EPUB, cómics, imágenes, textos, Office\u2026</span>"];
    [html appendString:@"<input type=\"file\" id=\"file\" multiple><div class=\"btn\" id=\"btn\">Elegir archivos</div></div>"];
    [html appendString:@"<div id=\"log\"></div><ul id=\"lista\">"];

    NSArray *archivos = [self listado];
    if (archivos.count == 0) {
        [html appendString:@"<li><span>Sin archivos todavía</span><span class=\"t\">\u2014</span></li>"];
    } else {
        for (NSDictionary *a in archivos) {
            NSString *nombre = a[@"name"];
            NSString *nombreJS = [nombre stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            [html appendFormat:@"<li><span>%@</span><span class=\"t\">%@ <a href=\"/download/%@\">descargar</a> <a href=\"#\" onclick=\"borrar('%@');return false;\">borrar</a></span></li>",
             nombre, [self tamanoLegible:a[@"size"]],
             [nombre stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]],
             nombreJS];
        }
    }
    [html appendString:@"</ul><script>"];
    [html appendString:@"var d=document.getElementById('drop'),f=document.getElementById('file'),b=document.getElementById('btn'),log=document.getElementById('log');"];
    [html appendString:@"b.onclick=function(e){e.preventDefault();f.click();};"];
    [html appendString:@"['dragenter','dragover'].forEach(function(n){d.addEventListener(n,function(e){e.preventDefault();d.classList.add('on');});});"];
    [html appendString:@"['dragleave','drop'].forEach(function(n){d.addEventListener(n,function(e){e.preventDefault();d.classList.remove('on');});});"];
    [html appendString:@"d.addEventListener('drop',function(e){subir(e.dataTransfer.files);});"];
    [html appendString:@"f.addEventListener('change',function(){subir(f.files);});"];
    [html appendString:@"function subir(fs){if(!fs.length)return;var i=0;function uno(){if(i>=fs.length){log.textContent='Listo. Recargando\u2026';setTimeout(function(){location.reload();},700);return;}"];
    [html appendString:@"var fd=new FormData();fd.append('file',fs[i]);log.textContent='Subiendo '+(i+1)+' de '+fs.length+'\u2026';"];
    [html appendString:@"fetch('/upload',{method:'POST',body:fd}).then(function(){i++;uno();}).catch(function(){i++;uno();});}uno();}"];
    [html appendString:@"function borrar(n){fetch('/file/'+encodeURIComponent(n),{method:'DELETE'}).then(function(){location.reload();});}"];
    [html appendString:@"</script></body></html>"];
    return html;
}

- (NSString *)tamanoLegible:(NSNumber *)bytes {
    unsigned long long b = [bytes unsignedLongLongValue];
    if (b < 1024) return [NSString stringWithFormat:@"%llu B", b];
    if (b < 1024 * 1024) return [NSString stringWithFormat:@"%.0f KB", b / 1024.0];
    return [NSString stringWithFormat:@"%.1f MB", b / (1024.0 * 1024.0)];
}

#pragma mark - Direcciones

- (NSArray<NSString *> *)urlList {
    NSMutableArray *salida = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        struct ifaddrs *actual = interfaces;
        while (actual) {
            if (actual->ifa_addr && actual->ifa_addr->sa_family == AF_INET) {
                NSString *nombre = [NSString stringWithUTF8String:actual->ifa_name];
                if ([nombre hasPrefix:@"en"] || [nombre hasPrefix:@"pdp_ip"]) {
                    struct sockaddr_in *dir = (struct sockaddr_in *)actual->ifa_addr;
                    char texto[INET_ADDRSTRLEN];
                    if (inet_ntop(AF_INET, &dir->sin_addr, texto, sizeof(texto))) {
                        NSString *ip = [NSString stringWithUTF8String:texto];
                        if (ip.length && ![ip isEqualToString:@"127.0.0.1"]) {
                            [salida addObject:[NSString stringWithFormat:@"http://%@:%ld", ip, (long)self.port]];
                        }
                    }
                }
            }
            actual = actual->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    return salida;
}

- (NSString *)bestURL {
    NSArray *lista = [self urlList];
    if (lista.count) return lista[0];
    return [NSString stringWithFormat:@"http://127.0.0.1:%ld", (long)self.port];
}

@end
