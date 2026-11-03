#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "IRModels.h"

// Visor de HTML, SVG y documentos Office respetando el CSS y las fuentes
// originales del propio fichero.
@interface IRWebReaderViewController : UIViewController <IRReader>

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, copy) void (^onFailure)(void);

@end
