#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Servidor HTTP minimo (solo GET y PUT/POST multipart) para recibir archivos
// desde el ordenador en la misma red Wi-Fi. Escucha en todas las interfaces.
@interface IRHTTPServer : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) NSInteger port;
@property (nonatomic, copy) NSString *uploadsDirectory;
@property (nonatomic, copy) void (^onFileUploaded)(NSString *path);

- (BOOL)startOnPort:(NSInteger)port uploadsDirectory:(NSString *)directory;
- (void)stop;

// Direcciones IPv4 útiles de este dispositivo ("http://192.168.1.20:8080").
- (NSArray<NSString *> *)urlList;
- (NSString *)bestURL;

@end
