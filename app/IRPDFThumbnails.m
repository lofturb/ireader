#import "IRPDFThumbnails.h"

@interface IRPDFThumbnails ()
@property (nonatomic, assign) CGPDFDocumentRef document;
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) dispatch_queue_t cola;
@end

@implementation IRPDFThumbnails

- (instancetype)initWithDocument:(CGPDFDocumentRef)document {
    self = [super init];
    if (self) {
        _document = document;
        if (_document) CGPDFDocumentRetain(_document);
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 120;
        _cola = dispatch_queue_create("com.lofturb.ireader.pdfthumbs", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    if (_document) CGPDFDocumentRelease(_document);
}

- (NSString *)claveParaPagina:(NSInteger)pagina size:(CGSize)size {
    return [NSString stringWithFormat:@"%ld|%.0fx%.0f", (long)pagina, size.width, size.height];
}

- (UIImage *)cachedThumbnailForPage:(NSInteger)page size:(CGSize)size {
    return [self.cache objectForKey:[self claveParaPagina:page size:size]];
}

- (void)thumbnailForPage:(NSInteger)page
                    size:(CGSize)size
              completion:(void (^)(UIImage *))completion {
    if (!completion) return;
    UIImage *guardada = [self cachedThumbnailForPage:page size:size];
    if (guardada) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(guardada); });
        return;
    }
    CGPDFDocumentRef documento = self.document;
    if (documento) CGPDFDocumentRetain(documento);
    dispatch_async(self.cola, ^{
        UIImage *imagen = nil;
        if (documento) {
            CGPDFPageRef paginaRef = CGPDFDocumentGetPage(documento, (size_t)page);
            if (paginaRef) {
                CGRect caja = CGPDFPageGetBoxRect(paginaRef, kCGPDFCropBox);
                if (caja.size.width <= 0 || caja.size.height <= 0) {
                    caja = CGPDFPageGetBoxRect(paginaRef, kCGPDFMediaBox);
                }
                int rot = CGPDFPageGetRotationAngle(paginaRef);
                if (rot == 90 || rot == 270) {
                    CGFloat t = caja.size.width;
                    caja.size.width = caja.size.height;
                    caja.size.height = t;
                }
                CGFloat escala = MIN(size.width / MAX(1, caja.size.width),
                                     size.height / MAX(1, caja.size.height));
                if (escala <= 0 || !isfinite(escala)) escala = 1;
                size_t w = (size_t)MAX(1, caja.size.width * escala);
                size_t h = (size_t)MAX(1, caja.size.height * escala);
                CGColorSpaceRef espacio = CGColorSpaceCreateDeviceRGB();
                CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, espacio,
                                                         kCGImageAlphaPremultipliedLast);
                CGColorSpaceRelease(espacio);
                if (ctx) {
                    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
                    CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
                    CGRect destino = CGRectMake(0, 0, w, h);
                    CGAffineTransform t = CGPDFPageGetDrawingTransform(paginaRef, kCGPDFCropBox, destino, 0, true);
                    CGContextConcatCTM(ctx, t);
                    CGContextDrawPDFPage(ctx, paginaRef);                    CGImageRef cg = CGBitmapContextCreateImage(ctx);
                    if (cg) {
                        imagen = [UIImage imageWithCGImage:cg];
                        CGImageRelease(cg);
                    }
                    CGContextRelease(ctx);
                }
            }
            CGPDFDocumentRelease(documento);
        }
        if (imagen) {
            [self.cache setObject:imagen forKey:[self claveParaPagina:page size:size]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(imagen); });
    });
}

@end
