#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRRootViewController : UIViewController

- (void)openDocument:(IRDocument *)document;
- (void)openDocument:(IRDocument *)document atPage:(NSInteger)page;
- (void)showFileBrowser;
- (void)showDetailsForDocument:(IRDocument *)document;

@end
