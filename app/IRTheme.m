#import "IRTheme.h"
#import "IRSettings.h"

NSString * const IRThemeDidChangeNotification = @"IRThemeDidChangeNotification";

@implementation IRTheme

+ (instancetype)shared {
    static IRTheme *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IRTheme alloc] init];
        instancia.dark = [IRSettings shared].appDark;
        instancia.readingTheme = [IRSettings shared].readingTheme;
    });
    return instancia;
}

+ (void)applyDark:(BOOL)dark {
    IRTheme *t = [IRTheme shared];
    t.dark = dark;
    [IRSettings shared].appDark = dark;
    [[NSNotificationCenter defaultCenter] postNotificationName:IRThemeDidChangeNotification
                                                        object:t];
}

- (void)setReadingTheme:(IRReadingTheme)readingTheme {
    _readingTheme = readingTheme;
    [IRSettings shared].readingTheme = readingTheme;
}

#pragma mark - Colores de interfaz

- (UIColor *)background {
    return self.dark ? [IRTheme colorWithHex:0x14120F alpha:1]
                     : [IRTheme colorWithHex:0xF6F1E7 alpha:1];
}
- (UIColor *)cardBackground {
    return self.dark ? [IRTheme colorWithHex:0x201D19 alpha:1]
                     : [IRTheme colorWithHex:0xFFFCF6 alpha:1];
}
- (UIColor *)elevatedBackground {
    return self.dark ? [IRTheme colorWithHex:0x2A2620 alpha:1]
                     : [IRTheme colorWithHex:0xFFFFFF alpha:1];
}
- (UIColor *)sidebarBackground {
    return self.dark ? [IRTheme colorWithHex:0x1A1815 alpha:1]
                     : [IRTheme colorWithHex:0xEFE7D8 alpha:1];
}
- (UIColor *)textPrimary {
    return self.dark ? [IRTheme colorWithHex:0xF1EBDF alpha:1]
                     : [IRTheme colorWithHex:0x231F1A alpha:1];
}
- (UIColor *)textSecondary {
    return self.dark ? [IRTheme colorWithHex:0xB9B1A2 alpha:1]
                     : [IRTheme colorWithHex:0x6E665A alpha:1];
}
- (UIColor *)textTertiary {
    return self.dark ? [IRTheme colorWithHex:0x807868 alpha:1]
                     : [IRTheme colorWithHex:0x9C9384 alpha:1];
}
- (UIColor *)separator {
    return self.dark ? [IRTheme colorWithHex:0x352F28 alpha:1]
                     : [IRTheme colorWithHex:0xE0D6C4 alpha:1];
}
- (UIColor *)accent {
    return [IRSettings shared].accentColor;
}
- (UIColor *)accentSoft {
    return [[IRSettings shared].accentColor colorWithAlphaComponent:0.16];
}
- (UIColor *)danger {
    return [IRTheme colorWithHex:0xC0453A alpha:1];
}
- (UIColor *)success {
    return [IRTheme colorWithHex:0x4E8C5A alpha:1];
}
- (UIColor *)warning {
    return [IRTheme colorWithHex:0xC98A2B alpha:1];
}
- (UIColor *)controlFill {
    return self.dark ? [IRTheme colorWithHex:0x2E2A24 alpha:1]
                     : [IRTheme colorWithHex:0xE9E0CF alpha:1];
}
- (UIColor *)selectionFill {
    return [[IRSettings shared].accentColor colorWithAlphaComponent:0.22];
}
- (UIColor *)fieldBackground {
    return self.dark ? [IRTheme colorWithHex:0x26221D alpha:1]
                     : [IRTheme colorWithHex:0xFFFFFF alpha:1];
}
- (UIColor *)overlay {
    return [UIColor colorWithWhite:0 alpha:self.dark ? 0.62 : 0.38];
}

#pragma mark - Colores de lectura

- (UIColor *)readingBackground {
    switch (self.readingTheme) {
        case IRReadingThemeOriginal: return [UIColor whiteColor];
        case IRReadingThemePaper:    return [IRTheme colorWithHex:0xFBF7EE alpha:1];
        case IRReadingThemeSepia:    return [IRTheme colorWithHex:0xF2E4C7 alpha:1];
        case IRReadingThemeNight:    return [IRTheme colorWithHex:0x141414 alpha:1];
        case IRReadingThemeBlack:    return [UIColor blackColor];
    }
    return [UIColor whiteColor];
}
- (UIColor *)readingText {
    switch (self.readingTheme) {
        case IRReadingThemeOriginal: return [IRTheme colorWithHex:0x1A1A1A alpha:1];
        case IRReadingThemePaper:    return [IRTheme colorWithHex:0x241F18 alpha:1];
        case IRReadingThemeSepia:    return [IRTheme colorWithHex:0x453320 alpha:1];
        case IRReadingThemeNight:    return [IRTheme colorWithHex:0xD9D3C6 alpha:1];
        case IRReadingThemeBlack:    return [IRTheme colorWithHex:0xBFB9AE alpha:1];
    }
    return [UIColor blackColor];
}
- (UIColor *)readingSecondary {
    return [self.readingText colorWithAlphaComponent:0.55];
}
- (BOOL)readingInverts {
    return self.readingTheme == IRReadingThemeNight || self.readingTheme == IRReadingThemeBlack;
}
- (BOOL)readingOverrides {
    return self.readingTheme != IRReadingThemeOriginal;
}

#pragma mark - Medidas

- (CGFloat)cornerRadius { return 10.0; }
- (CGFloat)largeCornerRadius { return 16.0; }
- (CGFloat)rowHeight { return 56.0; }
- (CGFloat)gutter { return 16.0; }
- (CGFloat)sidebarWidth { return 248.0; }

#pragma mark - Tipografia

- (UIFont *)fontNavTitle { return [UIFont fontWithName:@"Georgia-Bold" size:20] ?: [UIFont boldSystemFontOfSize:20]; }
- (UIFont *)fontTitle { return [UIFont fontWithName:@"Georgia-Bold" size:24] ?: [UIFont boldSystemFontOfSize:24]; }
- (UIFont *)fontHeadline { return [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; }
- (UIFont *)fontBody { return [UIFont systemFontOfSize:16]; }
- (UIFont *)fontSubhead { return [UIFont systemFontOfSize:14]; }
- (UIFont *)fontCaption { return [UIFont systemFontOfSize:12]; }
- (UIFont *)fontMono:(CGFloat)size { return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size]; }
- (UIFont *)fontSerif:(CGFloat)size { return [UIFont fontWithName:@"Georgia" size:size] ?: [UIFont systemFontOfSize:size]; }

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

+ (UIColor *)colorFromSeed:(NSUInteger)seed {
    static const NSUInteger palette[] = {
        0x8C5A3C, 0x3C6E71, 0x7A5C99, 0x9C6B3F, 0x4E7A5A,
        0x8A4B4B, 0x556B8C, 0x8C7A3C, 0x6B4E8C, 0x3F7A8C
    };
    NSUInteger cuenta = sizeof(palette) / sizeof(palette[0]);
    return [self colorWithHex:palette[seed % cuenta] alpha:1];
}

@end
