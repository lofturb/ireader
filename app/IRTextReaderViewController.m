#import "IRTextReaderViewController.h"
#import "IRTextPaginator.h"
#import "IRMarkdown.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"

@interface IRTextReaderViewController ()

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSAttributedString *rtfText;
@property (nonatomic, strong) IRTextPaginator *paginator;
@property (nonatomic, strong) NSArray<IRTOCItem *> *toc;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, assign) BOOL largeMode;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) CGSize lastPageSize;
@property (nonatomic, assign) CGFloat currentMargin;
@property (nonatomic, assign) BOOL restoring;

@end

@implementation IRTextReaderViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _pageIndex = 0;
        _toc = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].readingBackground;

    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.editable = NO;
    self.textView.selectable = NO;
    self.textView.scrollEnabled = NO;
    self.textView.textContainer.lineFragmentPadding = 0;
    self.textView.textContainerInset = UIEdgeInsetsZero;
    self.textView.userInteractionEnabled = NO;
    [self.view addSubview:self.textView];

    self.loadingLabel = [[UILabel alloc] init];
    self.loadingLabel.text = @"Abriendo documento\u2026";
    self.loadingLabel.font = [IRTheme shared].fontBody;
    self.loadingLabel.textColor = [IRTheme shared].readingSecondary;
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.loadingLabel];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [IRTheme shared].fontBody;
    self.errorLabel.textColor = [IRTheme shared].readingSecondary;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];

    UISwipeGestureRecognizer *izquierda =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    izquierda.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:izquierda];

    UISwipeGestureRecognizer *derecha =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    derecha.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:derecha];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification" object:nil];

    [self loadText];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.textView.frame = self.view.bounds;
    self.loadingLabel.frame = CGRectInset(self.view.bounds, 30, 0);
    self.loadingLabel.center = CGPointMake(self.view.bounds.size.width / 2,
                                           self.view.bounds.size.height / 2);
    self.errorLabel.frame = CGRectInset(self.view.bounds, 40, 80);

    if (!self.loaded || self.largeMode) return;
    CGSize tam = [self pageSizeForCurrentBounds];
    if (fabs(tam.width - self.lastPageSize.width) > 0.5 ||
        fabs(tam.height - self.lastPageSize.height) > 0.5) {
        [self rebuildPaginationPreservingOffset];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

#pragma mark - Carga

- (void)loadText {
    NSString *ruta = self.document.path;
    NSString *ext = ruta.pathExtension.lowercaseString;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *datos = [NSData dataWithContentsOfFile:ruta options:NSDataReadingMappedIfSafe error:NULL];
        if (!datos.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self failWithMessage:@"No se pudo leer el archivo de texto."];
            });
            return;
        }
        NSAttributedString *rtf = nil;
        if ([ext isEqualToString:@"rtf"]) {
            NSError *error = nil;
            rtf = [[NSAttributedString alloc] initWithData:datos
                                                    options:@{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}
                                         documentAttributes:NULL error:&error];
            if (!rtf) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self failWithMessage:@"No se pudo interpretar el documento RTF."];
                });
                return;
            }
        }
        NSString *texto = nil;
        if (!rtf) {
            texto = [IRUtils decodeTextAtPath:ruta encoding:NULL];
            if (!texto) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self failWithMessage:@"El archivo no parece texto legible. Puedes abrirlo en la vista hexadecimal."];
                });
                return;
            }
        }

        BOOL grande = (datos.length > 8 * 1024 * 1024);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.text = texto ?: rtf.string;
            self.rtfText = rtf;
            self.largeMode = grande;
            [self setupContent];
        });
    });
}

- (void)failWithMessage:(NSString *)mensaje {
    self.loadingLabel.hidden = YES;
    self.errorLabel.text = mensaje;
    self.errorLabel.hidden = NO;
    if (self.onFailure) self.onFailure();
}

- (void)setupContent {
    self.loadingLabel.hidden = YES;
    if (!self.text.length) {
        [self failWithMessage:@"El documento está vacío."];
        return;
    }
    self.loaded = YES;
    self.currentMargin = MAX(12, [IRSettings shared].readingMargin);

    if (self.largeMode) {
        self.textView.scrollEnabled = YES;
        self.textView.userInteractionEnabled = YES;
        self.textView.font = [self baseFont];
        self.textView.textColor = [IRTheme shared].readingText;
        self.textView.textContainerInset = [self textInsets];
        self.textView.text = self.text;
        [self.textView layoutIfNeeded];
        double ratio = self.document.progress.ratio;
        if (ratio > 0.001) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                CGFloat maxY = MAX(0, self.textView.contentSize.height - self.textView.bounds.size.height);
                [self.textView setContentOffset:CGPointMake(0, ratio * maxY) animated:NO];
            });
        }
        self.toc = [self buildTableOfContents];
        return;
    }

    CGSize tam = [self pageSizeForCurrentBounds];
    self.lastPageSize = tam;
    self.paginator = [[IRTextPaginator alloc] initWithAttributedString:[self buildAttributedText] size:tam];
    NSInteger pagina = self.document.progress.page;
    if (self.document.progress.index > 0) {
        pagina = [self.paginator pageForCharacterIndex:(NSUInteger)self.document.progress.index];
    }
    self.pageIndex = MAX(0, MIN(self.paginator.pageCount - 1, pagina - 1));
    self.toc = [self buildTableOfContents];
    [self displayCurrentPage];
}

#pragma mark - Tipografia

- (BOOL)isCodeFile {
    NSString *e = self.document.path.pathExtension.lowercaseString;
    NSArray *codigo = @[@"c", @"h", @"m", @"mm", @"cpp", @"hpp", @"swift", @"py", @"js",
                        @"css", @"sh", @"json", @"xml", @"plist", @"csv", @"yml", @"yaml",
                        @"ini", @"conf", @"tex"];
    return [codigo containsObject:e];
}

- (UIFont *)baseFont {
    IRSettings *a = [IRSettings shared];
    CGFloat tam = MAX(10, a.readingFontSize);
    if ([self isCodeFile]) {
        return [UIFont fontWithName:@"Menlo" size:MAX(11, tam * 0.82)]
               ?: [UIFont systemFontOfSize:MAX(11, tam * 0.82)];
    }
    NSString *familia = a.readingFontFamily ?: @"Georgia";
    if ([familia isEqualToString:@"System"]) {
        return [UIFont systemFontOfSize:tam];
    }
    UIFont *fuente = [UIFont fontWithName:familia size:tam];
    if (fuente) return fuente;
    return [UIFont fontWithName:@"Georgia" size:tam] ?: [UIFont systemFontOfSize:tam];
}

- (NSMutableParagraphStyle *)paragraphStyle {
    IRSettings *a = [IRSettings shared];
    NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
    p.lineSpacing = MAX(0, a.readingLineSpacing);
    p.alignment = a.readingJustify ? NSTextAlignmentJustified : NSTextAlignmentNatural;
    p.hyphenationFactor = a.readingHyphenate ? 0.85 : 0.0;
    p.paragraphSpacing = 4;
    return p;
}

- (NSAttributedString *)buildAttributedText {
    IRSettings *a = [IRSettings shared];
    UIColor *color = [IRTheme shared].readingText;
    UIFont *fuente = [self baseFont];
    NSString *ext = self.document.path.pathExtension.lowercaseString;

    NSMutableAttributedString *salida = nil;
    if (self.rtfText) {
        salida = [self.rtfText mutableCopy];
        if ([IRTheme shared].readingOverrides) {
            [salida addAttribute:NSForegroundColorAttributeName value:color
                           range:NSMakeRange(0, salida.length)];
        }
    } else if ([ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"]) {
        salida = [[IRMarkdown attributedStringFromMarkdown:self.text
                                                  baseFont:fuente
                                                 textColor:color
                                               accentColor:[IRTheme shared].accent] mutableCopy];
    } else {
        salida = [[NSMutableAttributedString alloc] initWithString:self.text
            attributes:@{NSFontAttributeName: fuente, NSForegroundColorAttributeName: color}];
    }

    if (salida.length == 0) return salida;

    // Aplica interlineado y justificacion conservando los estilos por parrafo
    // que ya traiga el Markdown o el RTF.
    NSMutableParagraphStyle *base = [self paragraphStyle];
    NSMutableArray *tramos = [NSMutableArray array];
    [salida enumerateAttribute:NSParagraphStyleAttributeName
                       inRange:NSMakeRange(0, salida.length)
                       options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        [tramos addObject:@[value ?: [NSNull null], [NSValue valueWithRange:range]]];
    }];
    for (NSArray *par in tramos) {
        id valor = par[0];
        NSRange rango = [par[1] rangeValue];
        NSMutableParagraphStyle *p = [base mutableCopy];
        if ([valor isKindOfClass:[NSParagraphStyle class]]) {
            NSParagraphStyle *original = valor;
            p.firstLineHeadIndent = original.firstLineHeadIndent;
            p.headIndent = original.headIndent;
            p.tabStops = original.tabStops;
            if (original.alignment != NSTextAlignmentNatural) p.alignment = original.alignment;
        }
        [salida addAttribute:NSParagraphStyleAttributeName value:p range:rango];
    }
    return salida;
}

- (UIEdgeInsets)textInsets {
    CGFloat m = MAX(12, [IRSettings shared].readingMargin);
    return UIEdgeInsetsMake(m + 26, m, m + 26, m);
}

- (CGSize)pageSizeForCurrentBounds {
    CGSize visible = self.view.bounds.size;
    if (visible.width < 10 || visible.height < 10) visible = [UIScreen mainScreen].bounds.size;
    UIEdgeInsets inset = [self textInsets];
    return CGSizeMake(MAX(40, visible.width - inset.left - inset.right),
                      MAX(40, visible.height - inset.top - inset.bottom));
}

- (void)displayCurrentPage {
    if (!self.paginator) return;
    self.textView.userInteractionEnabled = NO;
    self.textView.scrollEnabled = NO;
    self.textView.textContainerInset = [self textInsets];
    self.textView.attributedText = [self.paginator attributedStringForPage:self.pageIndex + 1];
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.textColor = [IRTheme shared].readingText;
    [self.textView setContentOffset:CGPointZero animated:NO];
}

#pragma mark - Paginacion

- (NSUInteger)currentCharacterOffset {
    if (self.largeMode) {
        double ratio = [self currentRatio];
        return (NSUInteger)(ratio * (double)self.text.length);
    }
    if (!self.paginator) return 0;
    return [self.paginator characterRangeForPage:self.pageIndex + 1].location;
}

- (double)currentRatio {
    if (!self.largeMode) {
        if (!self.paginator || self.paginator.pageCount == 0) return 0;
        return (double)(self.pageIndex + 1) / (double)self.paginator.pageCount;
    }
    CGFloat maxY = MAX(1, self.textView.contentSize.height - self.textView.bounds.size.height);
    return MAX(0, MIN(1, self.textView.contentOffset.y / maxY));
}

- (void)rebuildPaginationPreservingOffset {
    if (!self.loaded || self.largeMode) return;
    NSUInteger offset = [self currentCharacterOffset];
    CGSize tam = [self pageSizeForCurrentBounds];
    self.lastPageSize = tam;
    self.paginator = [[IRTextPaginator alloc] initWithAttributedString:[self buildAttributedText] size:tam];
    NSInteger pagina = [self.paginator pageForCharacterIndex:offset];
    self.pageIndex = MAX(0, MIN(self.paginator.pageCount - 1, pagina - 1));
    self.toc = [self buildTableOfContents];
    [self displayCurrentPage];
}

#pragma mark - Indice

- (NSArray<IRTOCItem *> *)buildTableOfContents {
    NSMutableArray *items = [NSMutableArray array];
    if (!self.text.length) return items;
    NSString *ext = self.document.path.pathExtension.lowercaseString;
    BOOL markdown = [ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"];
    NSRegularExpression *re = nil;
    if (markdown) {
        re = [NSRegularExpression regularExpressionWithPattern:@"(?m)^(#{1,6})\\s+(.+)$"
                                                        options:0 error:NULL];
    } else {
        re = [NSRegularExpression regularExpressionWithPattern:
              @"(?im)^(cap[ií]tulo|chapter|parte|part|secci[oó]n|section)\\s+([^\\n]{1,80})$"
                                                        options:0 error:NULL];
    }
    NSArray *matches = [re matchesInString:self.text options:0 range:NSMakeRange(0, self.text.length)];
    for (NSTextCheckingResult *m in matches) {
        if (items.count >= 500) break;
        NSString *titulo = nil;
        NSInteger nivel = 0;
        NSUInteger offset = m.range.location;
        if (markdown) {
            if (m.numberOfRanges < 3) continue;
            NSString *almohadillas = [self.text substringWithRange:[m rangeAtIndex:1]];
            nivel = MAX(0, (NSInteger)almohadillas.length - 1);
            titulo = [self.text substringWithRange:[m rangeAtIndex:2]];
        } else {
            if (m.numberOfRanges < 3) continue;
            titulo = [NSString stringWithFormat:@"%@ %@",
                      [self.text substringWithRange:[m rangeAtIndex:1]],
                      [self.text substringWithRange:[m rangeAtIndex:2]]];
        }
        titulo = [titulo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!titulo.length) continue;
        NSInteger pagina = self.largeMode ? [self estimatedPageForOffset:offset]
                                          : (self.paginator ? [self.paginator pageForCharacterIndex:offset] : 1);
        [items addObject:[IRTOCItem itemWithTitle:titulo page:pagina index:(NSInteger)offset
                                           anchor:@"" level:nivel]];
    }
    return items;
}

- (NSInteger)estimatedPageForOffset:(NSUInteger)offset {
    if (!self.text.length) return 1;
    NSInteger total = [self pageCount];
    return MAX(1, MIN(total, (NSInteger)(((double)offset / (double)self.text.length) * total) + 1));
}

#pragma mark - Gestos

- (void)swipeLeft:(UISwipeGestureRecognizer *)gesto {
    if (self.largeMode) return;
    if (self.pageIndex + 1 < self.paginator.pageCount) [self goToPage:self.pageIndex + 2];
}

- (void)swipeRight:(UISwipeGestureRecognizer *)gesto {
    if (self.largeMode) return;
    if (self.pageIndex > 0) [self goToPage:self.pageIndex];
}

#pragma mark - IRReader

- (void)saveProgressNow {
    if (!self.loaded || !self.text.length) return;
    IRProgress *p = self.document.progress;
    if (self.largeMode) {
        double ratio = [self currentRatio];
        p.ratio = ratio;
        p.page = [self currentPage];
        p.pageCount = [self pageCount];
        p.index = (NSInteger)(ratio * self.text.length);
        p.anchor = @"";
        p.finished = ratio > 0.985;
    } else {
        if (!self.paginator) return;
        NSRange r = [self.paginator characterRangeForPage:self.pageIndex + 1];
        p.page = self.pageIndex + 1;
        p.pageCount = self.paginator.pageCount;
        p.index = (NSInteger)r.location;
        p.ratio = (double)(self.pageIndex + 1) / (double)MAX(1, self.paginator.pageCount);
        NSString *texto = [self.paginator plainTextForPage:self.pageIndex + 1];
        p.anchor = texto.length > 160 ? [texto substringToIndex:160] : texto;
        p.finished = (self.pageIndex + 1 >= self.paginator.pageCount);
    }
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    if (self.largeMode) {
        return [NSString stringWithFormat:@"%d%%", (int)round([self currentRatio] * 100)];
    }
    return [NSString stringWithFormat:@"Pág. %ld de %ld",
            (long)(self.pageIndex + 1), (long)(self.paginator ? self.paginator.pageCount : 1)];
}

- (NSInteger)pageCount {
    if (self.largeMode) {
        CGFloat alto = MAX(1, self.textView.bounds.size.height);
        CGFloat total = self.textView.contentSize.height;
        return MAX(1, (NSInteger)ceil(total / alto));
    }
    return self.paginator ? MAX(1, self.paginator.pageCount) : 1;
}

- (NSInteger)currentPage {
    if (self.largeMode) {
        CGFloat alto = MAX(1, self.textView.bounds.size.height);
        return MAX(1, MIN([self pageCount], (NSInteger)(self.textView.contentOffset.y / alto) + 1));
    }
    return self.pageIndex + 1;
}

- (void)goToPage:(NSInteger)page {
    if (!self.loaded) return;
    if (self.largeMode) {
        NSInteger total = [self pageCount];
        NSInteger destino = MAX(1, MIN(total, page));
        CGFloat alto = self.textView.bounds.size.height;
        CGFloat maxY = MAX(0, self.textView.contentSize.height - alto);
        CGFloat y = (total <= 1) ? 0 : ((CGFloat)(destino - 1) / (CGFloat)(total - 1)) * maxY;
        [self.textView setContentOffset:CGPointMake(0, y) animated:NO];
        [self saveProgressNow];
        return;
    }
    if (!self.paginator) return;
    NSInteger indice = MAX(0, MIN(self.paginator.pageCount - 1, page - 1));
    if (indice == self.pageIndex) return;
    self.pageIndex = indice;
    [self displayCurrentPage];
    [self saveProgressNow];
}

- (NSArray<IRTOCItem *> *)tableOfContents { return self.toc ?: @[]; }

- (void)jumpToTOCItem:(IRTOCItem *)item {
    if (!item) return;
    if (self.largeMode) {
        NSInteger pagina = [self estimatedPageForOffset:(NSUInteger)MAX(0, item.index)];
        [self goToPage:pagina];
    } else {
        [self goToPage:item.page];
    }
}

- (BOOL)supportsBookmarks { return YES; }

- (void)addBookmarkWithNote:(NSString *)note {
    NSString *ancla = @"";
    if (self.largeMode) {
        NSUInteger offset = [self currentCharacterOffset];
        if (offset < self.text.length) {
            NSUInteger largo = MIN((NSUInteger)160, self.text.length - offset);
            ancla = [self.text substringWithRange:NSMakeRange(offset, largo)];
        }
    } else {
        ancla = [self.paginator plainTextForPage:self.pageIndex + 1];
        if (ancla.length > 160) ancla = [ancla substringToIndex:160];
    }
    IRBookmark *b = [IRBookmark bookmarkWithPage:[self currentPage]
                                           index:[self currentCharacterOffset]
                                          anchor:ancla
                                           label:[self pageLabel]
                                            note:note ?: @""];
    [self.document.bookmarks addObject:b];
    [[IRLibrary shared] save];
    [IRToast showIn:self.view message:@"Marcador guardado"];
}

- (BOOL)supportsSearch { return YES; }

- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *))completion {
    if (!completion) return;
    NSString *q = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!q.length) {
        completion(@[]);
        return;
    }
    NSString *texto = self.text;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *crudos = [NSMutableArray array];
        NSRange rango = NSMakeRange(0, texto.length);
        while (rango.length > 0 && crudos.count < 300) {
            NSRange encontrado = [texto rangeOfString:q options:NSCaseInsensitiveSearch range:rango];
            if (encontrado.location == NSNotFound) break;
            NSUInteger inicio = encontrado.location > 40 ? encontrado.location - 40 : 0;
            NSUInteger fin = MIN(texto.length, NSMaxRange(encontrado) + 80);
            NSString *contexto = [texto substringWithRange:NSMakeRange(inicio, fin - inicio)];
            contexto = [contexto stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [crudos addObject:@{
                @"range": [NSValue valueWithRange:encontrado],
                @"quote": [texto substringWithRange:encontrado],
                @"snippet": contexto
            }];
            NSUInteger siguiente = NSMaxRange(encontrado);
            if (siguiente >= texto.length) break;
            rango = NSMakeRange(siguiente, texto.length - siguiente);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *resultados = [NSMutableArray array];
            for (NSDictionary *d in crudos) {
                IRSearchResult *r = [[IRSearchResult alloc] init];
                NSRange rr = [d[@"range"] rangeValue];
                r.range = rr;
                r.index = rr.location;
                r.quote = d[@"quote"];
                r.snippet = d[@"snippet"];
                if (self.largeMode) {
                    r.page = [self estimatedPageForOffset:rr.location];
                } else {
                    r.page = self.paginator ? [self.paginator pageForCharacterIndex:rr.location] : 1;
                }
                [resultados addObject:r];
            }
            completion(resultados);
        });
    });
}

- (void)jumpToSearchResult:(IRSearchResult *)result {
    if (!result) return;
    if (self.largeMode) {
        [self.textView scrollRangeToVisible:result.range];
        return;
    }
    [self goToPage:result.page];
}

- (void)applyDisplaySettings {
    self.view.backgroundColor = [IRTheme shared].readingBackground;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.textColor = [IRTheme shared].readingText;
    self.loadingLabel.textColor = [IRTheme shared].readingSecondary;
    self.errorLabel.textColor = [IRTheme shared].readingSecondary;

    if (!self.loaded) return;
    if (self.largeMode) {
        self.textView.font = [self baseFont];
        self.textView.textColor = [IRTheme shared].readingText;
        self.textView.textContainerInset = [self textInsets];
        return;
    }
    [self rebuildPaginationPreservingOffset];
}

- (BOOL)isPaginated { return !self.largeMode; }

@end
