#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRFileBrowserViewController : UIViewController

@property (nonatomic, copy) void (^onImport)(IRDocument *document);
@property (nonatomic, copy) NSString *startPath;

@end
