#import <UIKit/UIKit.h>

@class IRRootViewController;

typedef NS_ENUM(NSInteger, IRLibraryFilter) {
    IRLibraryFilterAll = 0,
    IRLibraryFilterFavorites,
    IRLibraryFilterReading,
    IRLibraryFilterFinished,
    IRLibraryFilterCollection
};

@interface IRLibraryViewController : UIViewController

@property (nonatomic, weak) IRRootViewController *host;
@property (nonatomic, assign) IRLibraryFilter filter;
@property (nonatomic, copy) NSString *collectionName;
@property (nonatomic, copy) NSString *screenTitle;

- (void)setFilter:(IRLibraryFilter)filter collection:(NSString *)collection title:(NSString *)title;
- (void)reloadLibrary;

@end
