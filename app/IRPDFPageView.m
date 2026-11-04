#import "IRPDFPageView.h"
#import <QuartzCore/QuartzCore.h>

@interface IRPDFPageView ()
@property (nonatomic, assign) CGPDFDocumentRef document;
@end

@implementation IRPDFPageView

+ (Class)layerClass {
    return [CATiledLayer class];
}

- (instancetype)initWithDocument:(CGPDFDocumentRef)document
                            page:(NSInteger)page
                         inverts:(BOOL)inverts {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _document = document;
        if (_document) CGPDFDocumentRetain(_document);
        _pageNumber = page;
        _inverts = inverts;
        self.opaque = YES;
        self.backgroundColor = [UIColor whiteColor];
        self.contentMode = UIViewContentModeRedraw;
        CATiledLayer *capa = (CATiledLayer *)self.layer;
        capa.tileSize = CGSizeMake(512, 512);
        capa.levelsOfDetail = 4;
        capa.levelsOfDetailBias = 3;
        capa.contentsScale = [UIScreen mainScreen].scale;
        self.frame = CGRectMake(0, 0, [self pageSize].width, [self pageSize].height);
    }
    return self;
}

- (void)dealloc {
    if (_document) CGPDFDocumentRelease(_document);
}

- (CGSize)pageSize {
    return [IRPDFPageView pageSizeForDocument:self.document page:self.pageNumber];
}

+ (CGSize)pageSizeForDocument:(CGPDFDocumentRef)document page:(NSInteger)page {
    if (!document) return CGSizeMake(612, 792);
    CGPDFPageRef pagina = CGPDFDocumentGetPage(document, (size_t)MAX(1, page));
    if (!pagina) return CGSizeMake(612, 792);
    CGRect caja = CGPDFPageGetBoxRect(pagina, kCGPDFCropBox);
    if (caja.size.width <= 0 || caja.size.height <= 0) {
        caja = CGPDFPageGetBoxRect(pagina, kCGPDFMediaBox);
    }
    int rotacion = CGPDFPageGetRotationAngle(pagina);
    if (rotacion == 90 || rotacion == 270 || rotacion == -90 || rotacion == -270) {
        return CGSizeMake(caja.size.height, caja.size.width);
    }
    return CGSizeMake(MAX(1, caja.size.width), MAX(1, caja.size.height));
}

- (void)setPageNumber:(NSInteger)pageNumber {
    _pageNumber = pageNumber;
    [self.layer setNeedsDisplay];
}

- (void)setInverts:(BOOL)inverts {
    _inverts = inverts;
    [self.layer setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx || !self.document) return;
    @synchronized (self) {
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillRect(ctx, self.bounds);

        CGPDFPageRef pagina = CGPDFDocumentGetPage(self.document, (size_t)self.pageNumber);
        if (!pagina) return;

        CGContextSaveGState(ctx);
        // UIKit entrega el contexto con el eje Y invertido: hay que deshacer
        // esa inversion o la pagina se dibuja del reves (girada 180 grados).
        CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
        CGContextScaleCTM(ctx, 1, -1);
        CGAffineTransform transformacion =
            CGPDFPageGetDrawingTransform(pagina, kCGPDFCropBox, self.bounds, 0, true);
        CGContextConcatCTM(ctx, transformacion);
        CGContextDrawPDFPage(ctx, pagina);
        CGContextRestoreGState(ctx);

        if (self.inverts) {
            CGContextSetBlendMode(ctx, kCGBlendModeDifference);
            CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
            CGContextFillRect(ctx, self.bounds);
            CGContextSetBlendMode(ctx, kCGBlendModeNormal);
        }
    }
}

@end
