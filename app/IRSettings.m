#import "IRSettings.h"

static NSString * const kAppDark = @"appDark";
static NSString * const kAccentIndex = @"accentIndex";
static NSString * const kReadingTheme = @"readingTheme";
static NSString * const kReadingFontSize = @"readingFontSize";
static NSString * const kReadingFontFamily = @"readingFontFamily";
static NSString * const kReadingLineSpacing = @"readingLineSpacing";
static NSString * const kReadingMargin = @"readingMargin";
static NSString * const kReadingJustify = @"readingJustify";
static NSString * const kReadingHyphenate = @"readingHyphenate";
static NSString * const kReadingBrightness = @"readingBrightness";
static NSString * const kKeepAwake = @"keepAwake";
static NSString * const kOriginalLayout = @"originalLayout";
static NSString * const kPDFScrollDirection = @"pdfScrollDirection";
static NSString * const kPageTurnStyle = @"pageTurnStyle";
static NSString * const kLibraryView = @"libraryView";
static NSString * const kLibrarySort = @"librarySort";
static NSString * const kLibrarySortAscending = @"librarySortAscending";
static NSString * const kShowProgressBars = @"showProgressBars";
static NSString * const kShowOnlyReading = @"showOnlyReading";
static NSString * const kLastBookID = @"lastBookID";
static NSString * const kOpenLastBook = @"openLastBook";
static NSString * const kWifiPort = @"wifiPort";
static NSString * const kStatsEnabled = @"statsEnabled";

@implementation IRSettings

+ (instancetype)shared {
    static IRSettings *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IRSettings alloc] init];
        [instancia registrarValoresPorDefecto];
        [instancia cargar];
    });
    return instancia;
}

- (void)registrarValoresPorDefecto {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kAppDark: @NO,
        kAccentIndex: @0,
        kReadingTheme: @(IRReadingThemeOriginal),
        kReadingFontSize: @19,
        kReadingFontFamily: @"Georgia",
        kReadingLineSpacing: @6,
        kReadingMargin: @32,
        kReadingJustify: @NO,
        kReadingHyphenate: @YES,
        kReadingBrightness: @1.0,
        kKeepAwake: @NO,
        kOriginalLayout: @YES,
        kPDFScrollDirection: @(IRPDFScrollDirectionVertical),
        kPageTurnStyle: @(IRPageTurnStyleSlide),
        kLibraryView: @(IRLibraryViewModeGrid),
        kLibrarySort: @(IRLibrarySortRecent),
        kLibrarySortAscending: @YES,
        kShowProgressBars: @YES,
        kShowOnlyReading: @NO,
        kLastBookID: @"",
        kOpenLastBook: @NO,
        kWifiPort: @8080,
        kStatsEnabled: @YES
    }];
}

- (void)cargar {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    _appDark = [d boolForKey:kAppDark];
    _accentIndex = [d integerForKey:kAccentIndex];
    _readingTheme = (IRReadingTheme)[d integerForKey:kReadingTheme];
    _readingFontSize = [d doubleForKey:kReadingFontSize];
    _readingFontFamily = [d stringForKey:kReadingFontFamily] ?: @"Georgia";
    _readingLineSpacing = [d doubleForKey:kReadingLineSpacing];
    _readingMargin = [d doubleForKey:kReadingMargin];
    _readingJustify = [d boolForKey:kReadingJustify];
    _readingHyphenate = [d boolForKey:kReadingHyphenate];
    _readingBrightness = [d doubleForKey:kReadingBrightness];
    _keepAwake = [d boolForKey:kKeepAwake];
    _originalLayout = [d boolForKey:kOriginalLayout];
    _pdfScrollDirection = (IRPDFScrollDirection)[d integerForKey:kPDFScrollDirection];
    _pageTurnStyle = (IRPageTurnStyle)[d integerForKey:kPageTurnStyle];
    _libraryView = (IRLibraryViewMode)[d integerForKey:kLibraryView];
    _librarySort = (IRLibrarySortKey)[d integerForKey:kLibrarySort];
    _librarySortAscending = [d boolForKey:kLibrarySortAscending];
    _showProgressBars = [d boolForKey:kShowProgressBars];
    _showOnlyReading = [d boolForKey:kShowOnlyReading];
    _lastBookID = [d stringForKey:kLastBookID] ?: @"";
    _openLastBook = [d boolForKey:kOpenLastBook];
    _wifiPort = [d integerForKey:kWifiPort] ?: 8080;
    _statsEnabled = [d boolForKey:kStatsEnabled];
}

- (void)save {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:_appDark forKey:kAppDark];
    [d setInteger:_accentIndex forKey:kAccentIndex];
    [d setInteger:_readingTheme forKey:kReadingTheme];
    [d setDouble:_readingFontSize forKey:kReadingFontSize];
    [d setObject:_readingFontFamily forKey:kReadingFontFamily];
    [d setDouble:_readingLineSpacing forKey:kReadingLineSpacing];
    [d setDouble:_readingMargin forKey:kReadingMargin];
    [d setBool:_readingJustify forKey:kReadingJustify];
    [d setBool:_readingHyphenate forKey:kReadingHyphenate];
    [d setDouble:_readingBrightness forKey:kReadingBrightness];
    [d setBool:_keepAwake forKey:kKeepAwake];
    [d setBool:_originalLayout forKey:kOriginalLayout];
    [d setInteger:_pdfScrollDirection forKey:kPDFScrollDirection];
    [d setInteger:_pageTurnStyle forKey:kPageTurnStyle];
    [d setInteger:_libraryView forKey:kLibraryView];
    [d setInteger:_librarySort forKey:kLibrarySort];
    [d setBool:_librarySortAscending forKey:kLibrarySortAscending];
    [d setBool:_showProgressBars forKey:kShowProgressBars];
    [d setBool:_showOnlyReading forKey:kShowOnlyReading];
    [d setObject:_lastBookID forKey:kLastBookID];
    [d setBool:_openLastBook forKey:kOpenLastBook];
    [d setInteger:_wifiPort forKey:kWifiPort];
    [d setBool:_statsEnabled forKey:kStatsEnabled];
    [d synchronize];
}

- (void)resetReadingDefaults {
    _readingTheme = IRReadingThemeOriginal;
    _readingFontSize = 19;
    _readingFontFamily = @"Georgia";
    _readingLineSpacing = 6;
    _readingMargin = 32;
    _readingJustify = NO;
    _readingHyphenate = YES;
    _readingBrightness = 1.0;
    _originalLayout = YES;
    [self save];
}

- (UIColor *)accentColor {
    static const NSUInteger colores[] = {
        0xB4552F, // terracota (por defecto)
        0x2F6B63, // verde profundo
        0x5A4B8C, // ciruela
        0x2F5C8C, // azul
        0x7A6A2F  // oliva
    };
    NSUInteger cuenta = sizeof(colores) / sizeof(colores[0]);
    NSUInteger i = (NSUInteger)MAX(0, MIN((NSInteger)cuenta - 1, _accentIndex));
    return [IRTheme colorWithHex:colores[i] alpha:1];
}

@end
