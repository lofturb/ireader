#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

// Vista de una pagina PDF dibujada con CATiledLayer: nitidez total al ampliar
// sin cargar la pagina entera en memoria.
@interface IRPDFPageView : UIView

- (instancetype)initWithDocument:(CGPDFDocumentRef)document
                            page:(NSInteger)page
                         inverts:(BOOL)inverts;

@property (nonatomic, assign) NSInteger pageNumber;
@property (nonatomic, assign) BOOL inverts;
@property (nonatomic, readonly) CGSize pageSize;

@end
