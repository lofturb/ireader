#import <UIKit/UIKit.h>
#import "IRTheme.h"

typedef NS_ENUM(NSInteger, IRPageTurnStyle) {
    IRPageTurnStyleNone = 0,
    IRPageTurnStyleSlide,
    IRPageTurnStyleFade
};

typedef NS_ENUM(NSInteger, IRLibraryViewMode) {
    IRLibraryViewModeGrid = 0,
    IRLibraryViewModeList
};

typedef NS_ENUM(NSInteger, IRLibrarySortKey) {
    IRLibrarySortRecent = 0,
    IRLibrarySortTitle,
    IRLibrarySortAuthor,
    IRLibrarySortAdded
};

// Ajustes de la app, respaldados por NSUserDefaults.
@interface IRSettings : NSObject

+ (instancetype)shared;
- (void)save;
- (void)resetReadingDefaults;

@property (nonatomic, assign) BOOL appDark;
@property (nonatomic, assign) NSInteger accentIndex;
@property (nonatomic, readonly) UIColor *accentColor;

@property (nonatomic, assign) IRReadingTheme readingTheme;
@property (nonatomic, assign) CGFloat readingFontSize;
@property (nonatomic, copy)   NSString *readingFontFamily;
@property (nonatomic, assign) CGFloat readingLineSpacing;
@property (nonatomic, assign) CGFloat readingMargin;
@property (nonatomic, assign) BOOL readingJustify;
@property (nonatomic, assign) BOOL readingHyphenate;
@property (nonatomic, assign) CGFloat readingBrightness;
@property (nonatomic, assign) BOOL keepAwake;
// YES = renderiza el documento tal cual es (CSS y fuentes originales).
@property (nonatomic, assign) BOOL originalLayout;

@property (nonatomic, assign) IRPageTurnStyle pageTurnStyle;
@property (nonatomic, assign) IRLibraryViewMode libraryView;
@property (nonatomic, assign) IRLibrarySortKey librarySort;
@property (nonatomic, assign) BOOL librarySortAscending;
@property (nonatomic, assign) BOOL showProgressBars;
@property (nonatomic, assign) BOOL showOnlyReading;

@property (nonatomic, copy)   NSString *lastBookID;
@property (nonatomic, assign) BOOL openLastBook;

@property (nonatomic, assign) NSInteger wifiPort;
@property (nonatomic, assign) BOOL statsEnabled;

@end
