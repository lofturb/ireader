#import "IRTextPaginator.h"

@interface IRTextPaginator ()
@property (nonatomic, strong) NSTextStorage *storage;
@property (nonatomic, strong) NSLayoutManager *layoutManager;
@property (nonatomic, strong) NSMutableArray<NSValue *> *ranges;
@property (nonatomic, assign) NSInteger pageCount;
@property (nonatomic, assign) NSUInteger characterCount;
@end

@implementation IRTextPaginator

- (instancetype)initWithAttributedString:(NSAttributedString *)text size:(CGSize)size {
    self = [super init];
    if (self) {
        _ranges = [NSMutableArray array];
        _storage = [[NSTextStorage alloc] initWithAttributedString:text ?: [[NSAttributedString alloc] initWithString:@""]];
        _layoutManager = [[NSLayoutManager alloc] init];
        [_storage addLayoutManager:_layoutManager];
        _characterCount = _storage.length;
        if (size.width < 20 || size.height < 20) size = CGSizeMake(320, 480);
        [self paginarConTamano:size];
    }
    return self;
}

- (void)paginarConTamano:(CGSize)size {
    [self.ranges removeAllObjects];
    NSUInteger longitud = self.storage.length;
    if (longitud == 0) {
        self.pageCount = 1;
        [self.ranges addObject:[NSValue valueWithRange:NSMakeRange(0, 0)]];
        return;
    }

    NSUInteger localizacion = 0;
    NSInteger seguridad = 0;
    while (localizacion < longitud && seguridad++ < 20000) {
        NSTextContainer *contenedor = [[NSTextContainer alloc] initWithSize:size];
        contenedor.lineFragmentPadding = 0;
        contenedor.maximumNumberOfLines = 0;
        contenedor.lineBreakMode = NSLineBreakByWordWrapping;
        [self.layoutManager addTextContainer:contenedor];
        [self.layoutManager ensureLayoutForTextContainer:contenedor];

        NSRange rangoGlifos = [self.layoutManager glyphRangeForTextContainer:contenedor];
        if (rangoGlifos.length == 0) break;
        NSRange rangoChars = [self.layoutManager characterRangeForGlyphRange:rangoGlifos
                                                           actualGlyphRange:NULL];
        NSUInteger inicio = rangoChars.location;
        if (inicio < localizacion) inicio = localizacion;
        NSUInteger largo = rangoChars.length;
        if (inicio >= longitud) break;
        if (inicio + largo > longitud) largo = longitud - inicio;
        if (largo == 0) break;

        [self.ranges addObject:[NSValue valueWithRange:NSMakeRange(inicio, largo)]];
        localizacion = inicio + largo;
    }

    if (self.ranges.count == 0) {
        [self.ranges addObject:[NSValue valueWithRange:NSMakeRange(0, longitud)]];
    }
    self.pageCount = (NSInteger)self.ranges.count;
}

- (NSRange)characterRangeForPage:(NSInteger)page {
    if (self.ranges.count == 0) return NSMakeRange(0, 0);
    NSInteger i = MAX(0, MIN((NSInteger)self.ranges.count - 1, page - 1));
    return [self.ranges[(NSUInteger)i] rangeValue];
}

- (NSInteger)pageForCharacterIndex:(NSUInteger)index {
    if (self.ranges.count == 0) return 1;
    NSUInteger izq = 0;
    NSUInteger der = self.ranges.count - 1;
    while (izq < der) {
        NSUInteger medio = (izq + der) / 2;
        NSRange r = [self.ranges[medio] rangeValue];
        if (index < r.location) {
            der = medio;
        } else if (index >= r.location + r.length) {
            izq = medio + 1;
        } else {
            return (NSInteger)medio + 1;
        }
    }
    return (NSInteger)izq + 1;
}

- (NSAttributedString *)attributedStringForPage:(NSInteger)page {
    NSRange r = [self characterRangeForPage:page];
    if (r.location + r.length > self.storage.length) {
        r.length = self.storage.length - MIN(r.location, self.storage.length);
    }
    if (r.location > self.storage.length) return [[NSAttributedString alloc] initWithString:@""];
    return [self.storage attributedSubstringFromRange:r];
}

- (NSString *)plainTextForPage:(NSInteger)page {
    NSRange r = [self characterRangeForPage:page];
    if (r.location + r.length > self.storage.length) {
        r.length = self.storage.length - MIN(r.location, self.storage.length);
    }
    if (r.location > self.storage.length) return @"";
    return [self.storage.string substringWithRange:r];
}

@end
