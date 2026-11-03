#import <UIKit/UIKit.h>

@interface IRWiFiViewController : UIViewController

@property (nonatomic, copy) void (^onImport)(NSArray<NSString *> *paths);

@end
