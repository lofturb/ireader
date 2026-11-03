#import <Foundation/Foundation.h>

extern NSString * const IRArchiveErrorDomain;

typedef void (^IRArchiveProgress)(double fraction, NSString *currentName);
typedef BOOL (^IRArchiveCancel)(void);

// Lectura de ZIP con zlib (deflate/store). Sin dependencias externas.
@interface IRArchive : NSObject

// Cada diccionario: name, size, compressedSize, crc, method, isDirectory,
// localOffset (NSNumber).
+ (NSArray<NSDictionary *> *)listEntriesAtPath:(NSString *)zipPath
                                         error:(NSError **)error;

+ (NSData *)dataForEntry:(NSString *)entryName
                  atPath:(NSString *)zipPath
                   error:(NSError **)error;

+ (BOOL)extractArchive:(NSString *)zipPath
           toDirectory:(NSString *)destDir
              progress:(IRArchiveProgress)progress
                cancel:(IRArchiveCancel)cancel
                 error:(NSError **)error;

+ (BOOL)isZipAtPath:(NSString *)path;

@end
