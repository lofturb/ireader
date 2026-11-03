#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRImageReaderViewController : UIViewController <IRReader>

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, copy) void (^onFailure)(void);

@end
