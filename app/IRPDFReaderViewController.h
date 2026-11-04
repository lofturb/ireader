#import <UIKit/UIKit.h>
#import "IRModels.h"
#import "IRSettings.h"

@interface IRPDFReaderViewController : UIViewController <IRReader>

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, copy) void (^onFailure)(void);

// Vertical = flujo continuo (se baja leyendo). Horizontal = pagina a pagina.
@property (nonatomic, assign) IRPDFScrollDirection scrollDirection;
- (void)refreshLayoutForDirection;

@end
