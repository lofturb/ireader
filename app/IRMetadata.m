#import "IRMetadata.h"
#import "IRUtils.h"
#import "IREPUBDocument.h"
#import "IRArchive.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation IRMetadata

+ (void)loadMetadataForDocument:(IRDocument *)document
                     completion:(void (^)(UIImage *cover))completion {
    if (!document) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *portada = nil;
        @try {
            switch (document.type) {
                case IRDocumentTypePDF:
                    portada = [self pdfMetadata:document];
                    break;
                case IRDocumentTypeEPUB:
                    portada = [self epubMetadata:document];
                    break;
                case IRDocumentTypeImage:
                    portada = [IRUtils downsampleImageAtPath:document.path maxPixelSize:900];
                    document.progress.pageCount = 1;
                    break;
                case IRDocumentTypeComic:
                    portada = [self comicMetadata:document];
                    break;
                case IRDocumentTypeText:
                    [self textMetadata:document];
                    break;
                case IRDocumentTypeHTML:
                    [self htmlMetadata:document];
                    break;
                case IRDocumentTypeOffice:
                    [self officeMetadata:document];
                    break;
                default:
                    break;
            }
        } @catch (NSException *excepcion) {
            NSLog(@"[IReader] metadatos: %@", excepcion);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(portada); });
        }
    });
}

#pragma mark - PDF

+ (NSInteger)pageCountForPDFAtPath:(NSString *)path {
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path]);
    if (!pdf) return 0;
    NSInteger paginas = (NSInteger)CGPDFDocumentGetNumberOfPages(pdf);
    CGPDFDocumentRelease(pdf);
    return paginas;
}

+ (UIImage *)coverForPDFAtPath:(NSString *)path maxPixel:(CGFloat)maxPixel {
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path]);
    if (!pdf) return nil;
    UIImage *imagen = nil;
    if (CGPDFDocumentGetNumberOfPages(pdf) > 0) {
        CGPDFPageRef pagina = CGPDFDocumentGetPage(pdf, 1);
        if (pagina) {
            CGRect caja = CGPDFPageGetBoxRect(pagina, kCGPDFCropBox);
            if (caja.size.width <= 0 || caja.size.height <= 0) {
                caja = CGPDFPageGetBoxRect(pagina, kCGPDFMediaBox);
            }
            CGFloat escala = 1.0;
            if (caja.size.width > 0 && caja.size.height > 0) {
                escala = MIN(maxPixel / caja.size.width, maxPixel / caja.size.height);
            }
            if (escala <= 0 || !isfinite(escala)) escala = 1.0;
            CGSize tam = CGSizeMake(MAX(1, caja.size.width * escala),
                                    MAX(1, caja.size.height * escala));
            UIGraphicsBeginImageContextWithOptions(tam, YES, 1);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
            CGContextFillRect(ctx, CGRectMake(0, 0, tam.width, tam.height));
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, 0, tam.height);
            CGContextScaleCTM(ctx, escala, -escala);
            CGContextTranslateCTM(ctx, -caja.origin.x, -caja.origin.y);
            CGContextDrawPDFPage(ctx, pagina);
            CGContextRestoreGState(ctx);
            imagen = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    }
    CGPDFDocumentRelease(pdf);
    return imagen;
}

+ (UIImage *)pdfMetadata:(IRDocument *)document {
    NSInteger paginas = [self pageCountForPDFAtPath:document.path];
    if (paginas > 0) document.progress.pageCount = paginas;

    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:document.path]);
    if (pdf) {
        CGPDFDictionaryRef info = CGPDFDocumentGetInfo(pdf);
        if (info) {
            CGPDFStringRef valor = NULL;
            if (CGPDFDictionaryGetString(info, "Title", &valor) && valor) {
                NSString *titulo = CFBridgingRelease(CGPDFStringCopyTextString(valor));
                titulo = [titulo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (titulo.length > 1) document.title = titulo;
            }
            valor = NULL;
            if (CGPDFDictionaryGetString(info, "Author", &valor) && valor) {
                NSString *autor = CFBridgingRelease(CGPDFStringCopyTextString(valor));
                autor = [autor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (autor.length) document.author = autor;
            }
        }
        CGPDFDocumentRelease(pdf);
    }
    return [self coverForPDFAtPath:document.path maxPixel:900];
}

#pragma mark - EPUB

+ (UIImage *)epubMetadata:(IRDocument *)document {
    NSError *error = nil;
    IREPUBDocument *epub = [IREPUBDocument documentAtPath:document.path error:&error];
    if (!epub) return nil;
    if (epub.title.length) document.title = epub.title;
    if (epub.author.length) document.author = epub.author;
    document.progress.pageCount = MAX(1, epub.chapterCount);
    if (epub.coverPath.length) {
        return [IRUtils downsampleImageAtPath:epub.coverPath maxPixelSize:900];
    }
    return nil;
}

#pragma mark - Comic

+ (UIImage *)comicMetadata:(IRDocument *)document {
    NSError *error = nil;
    NSArray *entradas = [IRArchive listEntriesAtPath:document.path error:&error];
    if (!entradas) return nil;
    NSMutableArray *imagenes = [NSMutableArray array];
    for (NSDictionary *e in entradas) {
        if ([e[@"isDirectory"] boolValue]) continue;
        NSString *nombre = e[@"name"];
        if ([IRUtils isImagePath:nombre]) [imagenes addObject:e];
    }
    [imagenes sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [IRUtils naturalCompare:a[@"name"] with:b[@"name"]];
    }];
    document.progress.pageCount = MAX(1, (NSInteger)imagenes.count);
    if (!imagenes.count) return nil;
    NSDictionary *primera = imagenes.firstObject;
    NSData *datos = [IRArchive dataForEntry:primera[@"name"] atPath:document.path error:NULL];
    return [IRUtils downsampleImageFromData:datos maxPixelSize:900];
}

#pragma mark - Texto / HTML / Office

+ (void)textMetadata:(IRDocument *)document {
    NSString *texto = [IRUtils decodeTextAtPath:document.path encoding:NULL];
    if (!texto.length) return;
    NSString *primera = [IRUtils firstMeaningfulLine:texto];
    NSString *base = [[document.path lastPathComponent] stringByDeletingPathExtension];
    BOOL generico = ([base.lowercaseString hasPrefix:@"untitled"] ||
                     [base.lowercaseString hasPrefix:@"sin titulo"] ||
                     [base.lowercaseString hasPrefix:@"documento"]);
    if (generico && primera.length > 1) document.title = primera;
    if (primera.length > 1 && [base.lowercaseString isEqualToString:@"readme"]) {
        document.author = primera;
    }
}

+ (void)htmlMetadata:(IRDocument *)document {
    NSData *datos = [NSData dataWithContentsOfFile:document.path options:NSDataReadingMappedIfSafe error:NULL];
    if (!datos.length) return;
    NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    if (!texto.length) texto = [[NSString alloc] initWithData:datos encoding:NSISOLatin1StringEncoding];
    if (!texto.length) return;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"<title[^>]*>(.*?)</title>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:texto options:0 range:NSMakeRange(0, texto.length)];
    if (m && m.numberOfRanges > 1) {
        NSString *titulo = [[texto substringWithRange:[m rangeAtIndex:1]]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        titulo = [IRUtils stripHTML:titulo];
        if (titulo.length > 1) document.title = titulo;
    }
}

+ (void)officeMetadata:(IRDocument *)document {
    NSString *ext = [document.path.pathExtension lowercaseString];
    if (![ext isEqualToString:@"docx"] && ![ext isEqualToString:@"xlsx"] &&
        ![ext isEqualToString:@"pptx"] && ![ext isEqualToString:@"odt"] &&
        ![ext isEqualToString:@"ods"] && ![ext isEqualToString:@"odp"]) {
        return;
    }
    NSString *cache = [[IRUtils cachesPath] stringByAppendingPathComponent:
                       [IRUtils sha1OfString:[NSString stringWithFormat:@"office|%@", document.path]]];
    NSString *core = [cache stringByAppendingPathComponent:@"docProps/core.xml"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:core]) {
        [[NSFileManager defaultManager] removeItemAtPath:cache error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:nil error:NULL];
        [IRArchive extractArchive:document.path toDirectory:cache progress:nil cancel:nil error:NULL];
    }
    NSData *datos = [NSData dataWithContentsOfFile:core];
    if (!datos.length) return;
    NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    if (!texto.length) return;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"<dc:title[^>]*>(.*?)</dc:title>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:texto options:0 range:NSMakeRange(0, texto.length)];
    if (m && m.numberOfRanges > 1) {
        NSString *titulo = [[texto substringWithRange:[m rangeAtIndex:1]]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (titulo.length > 1) document.title = titulo;
    }
    re = [NSRegularExpression regularExpressionWithPattern:
        @"<dc:creator[^>]*>(.*?)</dc:creator>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:NULL];
    m = [re firstMatchInString:texto options:0 range:NSMakeRange(0, texto.length)];
    if (m && m.numberOfRanges > 1) {
        NSString *autor = [[texto substringWithRange:[m rangeAtIndex:1]]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (autor.length) document.author = autor;
    }
}

@end
