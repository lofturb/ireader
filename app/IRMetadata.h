#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "IRModels.h"

// Extrae titulo, autor, numero de paginas y portada de cada formato.
@interface IRMetadata : NSObject

+ (void)loadMetadataForDocument:(IRDocument *)document
                     completion:(void (^)(UIImage *cover))completion;

+ (UIImage *)coverForPDFAtPath:(NSString *)path maxPixel:(CGFloat)maxPixel;
+ (NSInteger)pageCountForPDFAtPath:(NSString *)path;

@end
