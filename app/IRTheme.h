#import <UIKit/UIKit.h>

extern NSString * const IRThemeDidChangeNotification;

typedef NS_ENUM(NSInteger, IRReadingTheme) {
    IRReadingThemeOriginal = 0,  // respeta el documento tal cual es
    IRReadingThemePaper,
    IRReadingThemeSepia,
    IRReadingThemeNight,
    IRReadingThemeBlack
};

// Sistema de diseno de IReader: colores, tipografia y medidas.
@interface IRTheme : NSObject

+ (instancetype)shared;
+ (void)applyDark:(BOOL)dark;

@property (nonatomic, assign) BOOL dark;
@property (nonatomic, assign) IRReadingTheme readingTheme;

// --- Colores de la interfaz ---
@property (nonatomic, readonly) UIColor *background;
@property (nonatomic, readonly) UIColor *cardBackground;
@property (nonatomic, readonly) UIColor *elevatedBackground;
@property (nonatomic, readonly) UIColor *sidebarBackground;
@property (nonatomic, readonly) UIColor *textPrimary;
@property (nonatomic, readonly) UIColor *textSecondary;
@property (nonatomic, readonly) UIColor *textTertiary;
@property (nonatomic, readonly) UIColor *separator;
@property (nonatomic, readonly) UIColor *accent;
@property (nonatomic, readonly) UIColor *accentSoft;
@property (nonatomic, readonly) UIColor *danger;
@property (nonatomic, readonly) UIColor *success;
@property (nonatomic, readonly) UIColor *warning;
@property (nonatomic, readonly) UIColor *controlFill;
@property (nonatomic, readonly) UIColor *selectionFill;
@property (nonatomic, readonly) UIColor *fieldBackground;
@property (nonatomic, readonly) UIColor *overlay;

// --- Colores de lectura ---
@property (nonatomic, readonly) UIColor *readingBackground;
@property (nonatomic, readonly) UIColor *readingText;
@property (nonatomic, readonly) UIColor *readingSecondary;
@property (nonatomic, readonly) BOOL readingInverts;   // PDF en modo noche
@property (nonatomic, readonly) BOOL readingOverrides; // false = tal cual es

// --- Medidas ---
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, readonly) CGFloat largeCornerRadius;
@property (nonatomic, readonly) CGFloat rowHeight;
@property (nonatomic, readonly) CGFloat gutter;
@property (nonatomic, readonly) CGFloat sidebarWidth;

// --- Tipografia ---
- (UIFont *)fontNavTitle;
- (UIFont *)fontTitle;
- (UIFont *)fontHeadline;
- (UIFont *)fontBody;
- (UIFont *)fontSubhead;
- (UIFont *)fontCaption;
- (UIFont *)fontMono:(CGFloat)size;
- (UIFont *)fontSerif:(CGFloat)size;

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;
+ (UIColor *)colorFromSeed:(NSUInteger)seed;

@end
