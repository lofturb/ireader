#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRBookCell : UICollectionViewCell

@property (nonatomic, assign) BOOL gridMode;
@property (nonatomic, strong, readonly) IRDocument *document;

- (void)configureWithDocument:(IRDocument *)document;
+ (UIImage *)coverImageForDocument:(IRDocument *)document size:(CGSize)size;

@end
