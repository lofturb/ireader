#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface IRPDFThumbnails : NSObject

- (instancetype)initWithDocument:(CGPDFDocumentRef)document;
- (UIImage *)cachedThumbnailForPage:(NSInteger)page size:(CGSize)size;
- (void)thumbnailForPage:(NSInteger)page
                    size:(CGSize)size
              completion:(void (^)(UIImage *image))completion;

@end
