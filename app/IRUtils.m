#import "IRUtils.h"
#import <ImageIO/ImageIO.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <string.h>

@implementation IRUtils

#pragma mark - Rutas

+ (NSString *)ensureDirectory:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:NULL];
    }
    return path;
}

+ (NSString *)documentsPath {
    NSString *p = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!p.length) p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    return [self ensureDirectory:p];
}

+ (NSString *)libraryPath {
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    if (!base.length) base = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    return [self ensureDirectory:[base stringByAppendingPathComponent:@"IReader"]];
}

+ (NSString *)libraryFile {
    return [[self libraryPath] stringByAppendingPathComponent:@"library.json"];
}

+ (NSString *)cachesPath {
    NSString *base = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    if (!base.length) base = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    return [self ensureDirectory:[base stringByAppendingPathComponent:@"IReader"]];
}

+ (NSString *)coversPath {
    return [self ensureDirectory:[[self cachesPath] stringByAppendingPathComponent:@"Covers"]];
}

+ (NSString *)epubCachePath {
    return [self ensureDirectory:[[self cachesPath] stringByAppendingPathComponent:@"EPUB"]];
}

+ (NSString *)thumbsPath {
    return [self ensureDirectory:[[self cachesPath] stringByAppendingPathComponent:@"Thumbs"]];
}

+ (NSString *)uploadsPath {
    return [self ensureDirectory:[[self documentsPath] stringByAppendingPathComponent:@"Subidas"]];
}

+ (NSString *)importedPath {
    return [self ensureDirectory:[[self documentsPath] stringByAppendingPathComponent:@"Importados"]];
}

+ (NSString *)sha1OfString:(NSString *)string {
    const char *cstr = [string UTF8String] ?: "";
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *salida = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [salida appendFormat:@"%02x", digest[i]];
    }
    return salida;
}

+ (NSString *)fileURLStringForPath:(NSString *)path {
    if (!path.length) return @"";
    NSURL *url = [NSURL fileURLWithPath:path];
    NSString *texto = url.absoluteString;
    return texto ?: @"";
}

+ (NSString *)uniquePathForName:(NSString *)name inDirectory:(NSString *)dir {
    NSString *destino = [dir stringByAppendingPathComponent:name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destino]) return destino;
    NSString *base = [name stringByDeletingPathExtension];
    NSString *ext = [name pathExtension];
    for (int i = 2; i < 10000; i++) {
        NSString *nuevo = ext.length ? [NSString stringWithFormat:@"%@ %d.%@", base, i, ext]
                                     : [NSString stringWithFormat:@"%@ %d", base, i];
        destino = [dir stringByAppendingPathComponent:nuevo];
        if (![[NSFileManager defaultManager] fileExistsAtPath:destino]) return destino;
    }
    return [dir stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
}

#pragma mark - Tipos

+ (IRDocumentType)typeForPath:(NSString *)path {
    BOOL esDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&esDir] && esDir) {
        return IRDocumentTypeFolder;
    }
    NSString *ext = [[path pathExtension] lowercaseString];
    if ([ext isEqualToString:@"pdf"]) return IRDocumentTypePDF;
    if ([ext isEqualToString:@"epub"]) return IRDocumentTypeEPUB;
    if ([ext isEqualToString:@"cbz"]) return IRDocumentTypeComic;
    if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"] || [ext isEqualToString:@"xhtml"] || [ext isEqualToString:@"svg"]) return IRDocumentTypeHTML;
    if ([ext isEqualToString:@"doc"] || [ext isEqualToString:@"docx"] || [ext isEqualToString:@"xls"] ||
        [ext isEqualToString:@"xlsx"] || [ext isEqualToString:@"ppt"] || [ext isEqualToString:@"pptx"] ||
        [ext isEqualToString:@"odt"] || [ext isEqualToString:@"ods"] || [ext isEqualToString:@"odp"] ||
        [ext isEqualToString:@"pages"] || [ext isEqualToString:@"key"] || [ext isEqualToString:@"numbers"]) {
        return IRDocumentTypeOffice;
    }
    if ([ext isEqualToString:@"zip"] || [ext isEqualToString:@"rar"] || [ext isEqualToString:@"7z"] ||
        [ext isEqualToString:@"tar"] || [ext isEqualToString:@"gz"]) return IRDocumentTypeArchive;
    if ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"] || [ext isEqualToString:@"aac"] ||
        [ext isEqualToString:@"wav"] || [ext isEqualToString:@"aif"] || [ext isEqualToString:@"aiff"] ||
        [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"] ||
        [ext isEqualToString:@"mpg"] || [ext isEqualToString:@"mpeg"]) return IRDocumentTypeMedia;
    if ([self isImagePath:path]) return IRDocumentTypeImage;
    if ([ext isEqualToString:@"txt"] || [ext isEqualToString:@"text"] || [ext isEqualToString:@"md"] ||
        [ext isEqualToString:@"markdown"] || [ext isEqualToString:@"rtf"] || [ext isEqualToString:@"csv"] ||
        [ext isEqualToString:@"json"] || [ext isEqualToString:@"xml"] || [ext isEqualToString:@"plist"] ||
        [ext isEqualToString:@"log"] || [ext isEqualToString:@"conf"] || [ext isEqualToString:@"ini"] ||
        [ext isEqualToString:@"yml"] || [ext isEqualToString:@"yaml"] || [ext isEqualToString:@"c"] ||
        [ext isEqualToString:@"h"] || [ext isEqualToString:@"m"] || [ext isEqualToString:@"mm"] ||
        [ext isEqualToString:@"cpp"] || [ext isEqualToString:@"hpp"] || [ext isEqualToString:@"swift"] ||
        [ext isEqualToString:@"py"] || [ext isEqualToString:@"js"] || [ext isEqualToString:@"css"] ||
        [ext isEqualToString:@"sh"] || [ext isEqualToString:@"tex"] || [ext isEqualToString:@"srt"] ||
        [ext isEqualToString:@"vtt"] || [ext isEqualToString:@"nfo"] || [ext isEqualToString:@"readme"] ||
        [ext length] == 0) {
        return IRDocumentTypeText;
    }
    return IRDocumentTypeUnknown;
}

+ (NSString *)typeName:(IRDocumentType)type {
    switch (type) {
        case IRDocumentTypePDF: return @"PDF";
        case IRDocumentTypeEPUB: return @"EPUB";
        case IRDocumentTypeText: return @"Texto";
        case IRDocumentTypeImage: return @"Imagen";
        case IRDocumentTypeComic: return @"Cómic";
        case IRDocumentTypeOffice: return @"Documento";
        case IRDocumentTypeHTML: return @"HTML";
        case IRDocumentTypeMedia: return @"Multimedia";
        case IRDocumentTypeArchive: return @"Archivo";
        case IRDocumentTypeFolder: return @"Carpeta";
        default: return @"Archivo";
    }
}

+ (IRGlyph)glyphForType:(IRDocumentType)type {
    switch (type) {
        case IRDocumentTypePDF: return IRGlyphFile;
        case IRDocumentTypeEPUB: return IRGlyphBook;
        case IRDocumentTypeText: return IRGlyphFile;
        case IRDocumentTypeImage: return IRGlyphImage;
        case IRDocumentTypeComic: return IRGlyphImage;
        case IRDocumentTypeOffice: return IRGlyphFile;
        case IRDocumentTypeHTML: return IRGlyphGlobe;
        case IRDocumentTypeMedia: return IRGlyphPlay;
        case IRDocumentTypeArchive: return IRGlyphFolder;
        case IRDocumentTypeFolder: return IRGlyphFolder;
        default: return IRGlyphFile;
    }
}

+ (BOOL)isImagePath:(NSString *)path {
    NSString *e = [[path pathExtension] lowercaseString];
    return [@[@"jpg", @"jpeg", @"png", @"gif", @"tif", @"tiff", @"bmp", @"ico", @"cur", @"webp"] containsObject:e];
}
+ (BOOL)isTextPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeText; }
+ (BOOL)isOfficePath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeOffice; }
+ (BOOL)isComicPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeComic; }
+ (BOOL)isPDFPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypePDF; }
+ (BOOL)isEPUBPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeEPUB; }
+ (BOOL)isHTMLPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeHTML; }
+ (BOOL)isMediaPath:(NSString *)path { return [self typeForPath:path] == IRDocumentTypeMedia; }

+ (BOOL)isSupportedPath:(NSString *)path {
    IRDocumentType t = [self typeForPath:path];
    return t != IRDocumentTypeUnknown && t != IRDocumentTypeArchive;
}

#pragma mark - Texto y fechas

+ (NSString *)fileSizeString:(unsigned long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    double kb = bytes / 1024.0;
    if (kb < 1024) return [NSString stringWithFormat:@"%.0f KB", kb];
    double mb = kb / 1024.0;
    if (mb < 1024) return [NSString stringWithFormat:@"%.1f MB", mb];
    return [NSString stringWithFormat:@"%.2f GB", mb / 1024.0];
}

+ (NSString *)dateString:(NSDate *)date {
    static NSDateFormatter *f = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"es_ES"];
        f.dateFormat = @"d MMM yyyy";
    });
    return date ? [f stringFromDate:date] : @"";
}

+ (NSString *)relativeDateString:(NSDate *)date {
    if (!date) return @"";
    NSCalendar *cal = [NSCalendar currentCalendar];
    if ([cal isDateInToday:date]) return @"Hoy";
    if ([cal isDateInYesterday:date]) return @"Ayer";
    NSDateComponents *c = [cal components:NSCalendarUnitDay fromDate:date toDate:[NSDate date] options:0];
    if (c.day > 0 && c.day < 7) return [NSString stringWithFormat:@"Hace %ld días", (long)c.day];
    return [self dateString:date];
}

+ (NSString *)decodeTextAtPath:(NSString *)path encoding:(NSStringEncoding *)encoding {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if (!data.length) {
        if (encoding) *encoding = NSUTF8StringEncoding;
        return @"";
    }
    // Binario con NUL: no es texto.
    const unsigned char *bytes = data.bytes;
    NSUInteger limite = MIN(data.length, (NSUInteger)4096);
    for (NSUInteger i = 0; i < limite; i++) {
        if (bytes[i] == 0) return nil;
    }
    NSStringEncoding lista[] = {
        NSUTF8StringEncoding,
        NSUTF16StringEncoding,
        NSUTF16LittleEndianStringEncoding,
        NSUTF16BigEndianStringEncoding,
        NSWindowsCP1252StringEncoding,
        NSISOLatin1StringEncoding,
        NSMacOSRomanStringEncoding
    };
    for (int i = 0; i < (int)(sizeof(lista) / sizeof(lista[0])); i++) {
        NSString *s = [[NSString alloc] initWithData:data encoding:lista[i]];
        if (s) {
            if (encoding) *encoding = lista[i];
            if ([s hasPrefix:@"\uFEFF"]) s = [s substringFromIndex:1];
            return s;
        }
    }
    return nil;
}

+ (NSString *)stripHTML:(NSString *)html {
    if (!html.length) return @"";
    NSString *s = html;
    s = [s stringByReplacingOccurrencesOfString:@"<br" withString:@"\n<br" options:NSCaseInsensitiveSearch range:NSMakeRange(0, s.length)];
    s = [s stringByReplacingOccurrencesOfString:@"</p>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, s.length)];
    s = [s stringByReplacingOccurrencesOfString:@"</div>" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, s.length)];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    s = [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
    NSArray *pares = @[@[@"&nbsp;", @" "], @[@"&amp;", @"&"], @[@"&lt;", @"<"], @[@"&gt;", @">"],
                       @[@"&quot;", @"\""], @[@"&#39;", @"'"], @[@"&apos;", @"'"], @[@"&mdash;", @"\u2014"],
                       @[@"&ndash;", @"\u2013"], @[@"&hellip;", @"\u2026"]];
    for (NSArray *p in pares) s = [s stringByReplacingOccurrencesOfString:p[0] withString:p[1]];
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)firstMeaningfulLine:(NSString *)text {
    NSArray *lineas = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *l in lineas) {
        NSString *t = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length < 2) continue;
        if ([t hasPrefix:@"---"] || [t hasPrefix:@"```"]) continue;
        while ([t hasPrefix:@"#"] || [t hasPrefix:@">"] || [t hasPrefix:@"-"] || [t hasPrefix:@"*"]) {
            t = [[t substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        if (t.length) return t.length > 120 ? [t substringToIndex:120] : t;
    }
    return @"";
}

+ (NSString *)jsonEscaped:(NSString *)string {
    NSMutableString *s = [NSMutableString stringWithString:string ?: @""];
    [s replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\u2028" withString:@"\\u2028" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\u2029" withString:@"\\u2029" options:0 range:NSMakeRange(0, s.length)];
    return s;
}

+ (NSComparisonResult)naturalCompare:(NSString *)a with:(NSString *)b {
    return [a compare:b options:NSCaseInsensitiveSearch | NSNumericSearch];
}

#pragma mark - Imagenes

+ (UIImage *)downsampleImageFromData:(NSData *)data maxPixelSize:(CGFloat)maxPixel {
    if (!data.length) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;
    NSDictionary *opts = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixel),
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceShouldCacheImmediately: @YES
    };
    CGImageRef img = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(source);
    if (!img) return nil;
    UIImage *salida = [UIImage imageWithCGImage:img scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(img);
    return salida;
}

+ (UIImage *)downsampleImageAtPath:(NSString *)path maxPixelSize:(CGFloat)maxPixel {
    if (!path.length) return nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return nil;
    NSDictionary *opts = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixel),
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceShouldCacheImmediately: @YES
    };
    CGImageRef img = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(source);
    if (!img) return nil;
    UIImage *salida = [UIImage imageWithCGImage:img scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(img);
    return salida;
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Varios

+ (BOOL)isLandscape {
    CGSize s = [UIScreen mainScreen].bounds.size;
    return s.width > s.height;
}

+ (CGFloat)statusBarHeight {
    CGFloat h = [UIApplication sharedApplication].statusBarFrame.size.height;
    return MAX(20, h);
}

+ (void)runOnMain:(dispatch_block_t)block {
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

+ (void)runInBackground:(dispatch_block_t)block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

+ (NSString *)formatDuration:(NSTimeInterval)seconds {
    NSInteger s = (NSInteger)MAX(0, seconds);
    NSInteger h = s / 3600;
    NSInteger m = (s % 3600) / 60;
    NSInteger sec = s % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)sec];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)sec];
}

@end
