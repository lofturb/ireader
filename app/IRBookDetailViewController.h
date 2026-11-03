#import <UIKit/UIKit.h>
#import "IRModels.h"

@class IRRootViewController;

@interface IRBookDetailViewController : UIViewController

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, weak) IRRootViewController *host;
@property (nonatomic, copy) void (^onClose)(void);

@end
