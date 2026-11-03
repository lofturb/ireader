#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRHexReaderViewController : UIViewController <IRReader>

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, copy) void (^onFailure)(void);

@end
