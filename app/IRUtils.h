#import <UIKit/UIKit.h>
#import "IRModels.h"
#import "IRIcons.h"

@interface IRUtils : NSObject

// --- Rutas ---
+ (NSString *)documentsPath;
+ (NSString *)libraryPath;
+ (NSString *)libraryFile;
+ (NSString *)cachesPath;
+ (NSString *)coversPath;
+ (NSString *)epubCachePath;
+ (NSString *)thumbsPath;
+ (NSString *)uploadsPath;
+ (NSString *)importedPath;
+ (NSString *)sha1OfString:(NSString *)string;
+ (NSString *)fileURLStringForPath:(NSString *)path;
+ (NSString *)uniquePathForName:(NSString *)name inDirectory:(NSString *)dir;

// --- Tipos ---
+ (IRDocumentType)typeForPath:(NSString *)path;
+ (NSString *)typeName:(IRDocumentType)type;
+ (IRGlyph)glyphForType:(IRDocumentType)type;
+ (BOOL)isImagePath:(NSString *)path;
+ (BOOL)isTextPath:(NSString *)path;
+ (BOOL)isOfficePath:(NSString *)path;
+ (BOOL)isComicPath:(NSString *)path;
+ (BOOL)isPDFPath:(NSString *)path;
+ (BOOL)isEPUBPath:(NSString *)path;
+ (BOOL)isHTMLPath:(NSString *)path;
+ (BOOL)isMediaPath:(NSString *)path;
+ (BOOL)isSupportedPath:(NSString *)path;

// --- Texto y fechas ---
+ (NSString *)fileSizeString:(unsigned long long)bytes;
+ (NSString *)dateString:(NSDate *)date;
+ (NSString *)relativeDateString:(NSDate *)date;
+ (NSString *)decodeTextAtPath:(NSString *)path encoding:(NSStringEncoding *)encoding;
+ (NSString *)stripHTML:(NSString *)html;
+ (NSString *)firstMeaningfulLine:(NSString *)text;
+ (NSString *)jsonEscaped:(NSString *)string;
+ (NSComparisonResult)naturalCompare:(NSString *)a with:(NSString *)b;

// --- Imagenes ---
+ (UIImage *)downsampleImageAtPath:(NSString *)path maxPixelSize:(CGFloat)maxPixel;
+ (UIImage *)downsampleImageFromData:(NSData *)data maxPixelSize:(CGFloat)maxPixel;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

// --- Varios ---
+ (BOOL)isLandscape;
+ (CGFloat)statusBarHeight;
+ (void)runOnMain:(dispatch_block_t)block;
+ (void)runInBackground:(dispatch_block_t)block;
+ (NSString *)formatDuration:(NSTimeInterval)seconds;

@end
