#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "IRModels.h"

@interface IRPDFOutline : NSObject

+ (NSArray<IRTOCItem *> *)itemsForDocument:(CGPDFDocumentRef)document;

@end
