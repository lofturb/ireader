#import "IRPDFReaderViewController.h"
#import "IRPDFPageView.h"
#import "IRPDFOutline.h"
#import "IRPDFThumbnails.h"
#import "IRTheme.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"

@interface IRPDFReaderViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) IRPDFPageView *pageView;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) NSArray<IRTOCItem *> *outline;
@property (nonatomic, strong) IRPDFThumbnails *thumbnails;
@property (nonatomic, assign) CGPDFDocumentRef pdf;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, assign) NSInteger pageCount;
@property (nonatomic, assign) CGFloat fitScale;
@property (nonatomic, assign) BOOL unlocked;
@property (nonatomic, assign) BOOL didInitialLayout;
@property (nonatomic, assign) BOOL failed;
@end

@implementation IRPDFReaderViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _pageIndex = 0;
        _fitScale = 1;
        _outline = @[];
    }
    return self;
}

- (void)dealloc {
    if (_pdf) CGPDFDocumentRelease(_pdf);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].readingBackground;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [IRTheme shared].readingBackground;
    self.scrollView.delegate = self;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.scrollView.bouncesZoom = YES;
    self.scrollView.maximumZoomScale = 5;
    self.scrollView.minimumZoomScale = 1;
    [self.view addSubview:self.scrollView];

    UISwipeGestureRecognizer *izquierda =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    izquierda.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.scrollView addGestureRecognizer:izquierda];

    UISwipeGestureRecognizer *derecha =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    derecha.direction = UISwipeGestureRecognizerDirectionRight;
    [self.scrollView addGestureRecognizer:derecha];

    UITapGestureRecognizer *doble =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
    doble.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doble];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [IRTheme shared].fontBody;
    self.errorLabel.textColor = [IRTheme shared].readingSecondary;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification"
                                               object:nil];

    [self loadDocument];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.errorLabel.frame = CGRectInset(self.view.bounds, 40, 80);
    if (!self.didInitialLayout && self.pdf && self.pageView) {
        self.didInitialLayout = YES;
        [self configurePageForDisplay];
    } else if (self.pdf && self.pageView) {
        [self adjustForSizeChange];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

#pragma mark - Carga

- (void)loadDocument {
    if (!self.document.path.length) {
        [self failWithMessage:@"No se encontró el archivo PDF."];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:self.document.path];
    self.pdf = CGPDFDocumentCreateWithURL((__bridge CFURLRef)url);
    if (!self.pdf) {
        [self failWithMessage:@"No se pudo abrir el PDF. Puede estar dañado o usar una protección no soportada."];
        return;
    }
    self.pageCount = (NSInteger)CGPDFDocumentGetNumberOfPages(self.pdf);
    if (self.pageCount <= 0) {
        [self failWithMessage:@"El PDF no contiene páginas."];
        return;
    }
    self.thumbnails = [[IRPDFThumbnails alloc] initWithDocument:self.pdf];
    self.outline = [IRPDFOutline itemsForDocument:self.pdf];

    NSInteger pagina = MAX(1, MIN(self.pageCount, self.document.progress.page));
    self.pageIndex = pagina - 1;
    self.unlocked = !CGPDFDocumentIsEncrypted(self.pdf) || CGPDFDocumentIsUnlocked(self.pdf);

    [self showPageAtIndex:self.pageIndex restorePosition:YES];
    if (!self.unlocked) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self requestPassword];
        });
    }
}

- (void)showPageAtIndex:(NSInteger)index restorePosition:(BOOL)restore {
    if (!self.pdf) return;
    if (index < 0) index = 0;
    if (index >= self.pageCount) index = self.pageCount - 1;
    self.pageIndex = index;

    [self.pageView removeFromSuperview];
    self.pageView = [[IRPDFPageView alloc] initWithDocument:self.pdf
                                                       page:index + 1
                                                    inverts:[self shouldInvert]];
    CGSize tam = self.pageView.pageSize;
    self.pageView.frame = CGRectMake(0, 0, tam.width, tam.height);
    [self.scrollView addSubview:self.pageView];
    [self.scrollView setZoomScale:1 animated:NO];
    self.scrollView.contentSize = tam;
    [self configurePageForDisplay];

    if (restore) {
        double factor = self.document.progress.zoom;
        if (factor > 1.01 && factor < 6) {
            self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale,
                                            MAX(self.scrollView.minimumZoomScale,
                                                self.fitScale * factor));
            [self centerContent];
        }
        CGPoint guardado = self.document.progress.offset;
        if (guardado.x > 0.001 || guardado.y > 0.001) {
            [self restoreNormalizedOffset:guardado];
        }
    }
    [self applyDisplaySettings];
}

- (void)configurePageForDisplay {
    if (!self.pageView) return;
    CGSize pagina = self.pageView.pageSize;
    CGSize visible = self.scrollView.bounds.size;
    if (visible.width < 10 || visible.height < 10) visible = self.view.bounds.size;
    CGFloat escala = MIN(visible.width / MAX(1, pagina.width),
                         visible.height / MAX(1, pagina.height));
    if (escala <= 0 || !isfinite(escala)) escala = 1;
    self.fitScale = escala;
    self.scrollView.contentSize = pagina;
    self.scrollView.minimumZoomScale = escala;
    self.scrollView.maximumZoomScale = MAX(3.0, escala * 5.0);
    self.scrollView.zoomScale = escala;
    [self centerContent];
}

- (void)adjustForSizeChange {
    if (!self.pageView) return;
    CGFloat relativo = self.scrollView.zoomScale / MAX(0.0001, self.fitScale);
    CGSize pagina = self.pageView.pageSize;
    CGSize visible = self.scrollView.bounds.size;
    CGFloat escala = MIN(visible.width / MAX(1, pagina.width),
                         visible.height / MAX(1, pagina.height));
    if (escala <= 0 || !isfinite(escala)) escala = 1;
    self.fitScale = escala;
    self.scrollView.minimumZoomScale = escala;
    self.scrollView.maximumZoomScale = MAX(3.0, escala * 5.0);
    CGFloat objetivo = MAX(escala, MIN(self.scrollView.maximumZoomScale, escala * relativo));
    self.scrollView.zoomScale = objetivo;
    [self centerContent];
}

- (void)centerContent {
    CGFloat ancho = self.scrollView.contentSize.width;
    CGFloat alto = self.scrollView.contentSize.height;
    CGFloat bx = self.scrollView.bounds.size.width;
    CGFloat by = self.scrollView.bounds.size.height;
    CGFloat ix = MAX(0, (bx - ancho) / 2);
    CGFloat iy = MAX(0, (by - alto) / 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(iy, ix, iy, ix);
}

- (void)restoreNormalizedOffset:(CGPoint)normalizado {
    CGFloat scrollableW = MAX(1, self.scrollView.contentSize.width - self.scrollView.bounds.size.width +
                              self.scrollView.contentInset.left + self.scrollView.contentInset.right);
    CGFloat scrollableH = MAX(1, self.scrollView.contentSize.height - self.scrollView.bounds.size.height +
                              self.scrollView.contentInset.top + self.scrollView.contentInset.bottom);
    CGFloat x = MAX(0, MIN(1, normalizado.x)) * scrollableW - self.scrollView.contentInset.left;
    CGFloat y = MAX(0, MIN(1, normalizado.y)) * scrollableH - self.scrollView.contentInset.top;
    [self.scrollView setContentOffset:CGPointMake(x, y) animated:NO];
}

- (CGPoint)normalizedOffset {
    CGFloat scrollableW = MAX(1, self.scrollView.contentSize.width - self.scrollView.bounds.size.width +
                              self.scrollView.contentInset.left + self.scrollView.contentInset.right);
    CGFloat scrollableH = MAX(1, self.scrollView.contentSize.height - self.scrollView.bounds.size.height +
                              self.scrollView.contentInset.top + self.scrollView.contentInset.bottom);
    CGFloat x = (self.scrollView.contentOffset.x + self.scrollView.contentInset.left) / scrollableW;
    CGFloat y = (self.scrollView.contentOffset.y + self.scrollView.contentInset.top) / scrollableH;
    return CGPointMake(MAX(0, MIN(1, x)), MAX(0, MIN(1, y)));
}

- (void)failWithMessage:(NSString *)mensaje {
    self.failed = YES;
    self.errorLabel.text = mensaje;
    self.errorLabel.hidden = NO;
    if (self.onFailure) self.onFailure();
}

#pragma mark - Contraseña

- (void)requestPassword {
    if (self.unlocked || !self.pdf) return;
    IRDialog *dialogo = [IRDialog alertWithTitle:@"PDF protegido"
                                         message:@"Este documento necesita una contraseña para abrirse."];
    dialogo.dismissOnTapOutside = NO;
    UITextField *campo = [dialogo addTextFieldWithPlaceholder:@"Contraseña" text:@"" secure:YES];
    [dialogo addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:^{
        if (self.onFailure) self.onFailure();
    }];
    [dialogo addAction:@"Abrir" style:IRDialogActionStyleSelected handler:^{
        NSString *texto = campo.text ?: @"";
        if (CGPDFDocumentUnlockWithPassword(self.pdf, texto.UTF8String)) {
            self.unlocked = YES;
            self.pageCount = (NSInteger)CGPDFDocumentGetNumberOfPages(self.pdf);
            self.outline = [IRPDFOutline itemsForDocument:self.pdf];
            [self showPageAtIndex:self.pageIndex restorePosition:YES];
            [IRToast showIn:self.view message:@"PDF desbloqueado"];
        } else {
            IRDialog *error = [IRDialog alertWithTitle:@"Contraseña incorrecta"
                                               message:@"Vuelve a intentarlo o cancela para salir."];
            [error addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:^{
                if (self.onFailure) self.onFailure();
            }];
            [error addAction:@"Reintentar" style:IRDialogActionStyleSelected handler:^{
                [self requestPassword];
            }];
            [error presentIn:self];
        }
    }];
    [dialogo presentIn:self];
}

#pragma mark - Gestos

- (void)swipeLeft:(UISwipeGestureRecognizer *)gesto {
    if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale * 1.06) return;
    if (self.pageIndex + 1 < self.pageCount) {
        [self goToPage:self.pageIndex + 2];
    }
}

- (void)swipeRight:(UISwipeGestureRecognizer *)gesto {
    if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale * 1.06) return;
    if (self.pageIndex > 0) {
        [self goToPage:self.pageIndex];
    }
}

- (void)doubleTapped:(UITapGestureRecognizer *)gesto {
    if (!self.pageView) return;
    if (self.scrollView.zoomScale <= self.scrollView.minimumZoomScale * 1.08) {
        CGPoint p = [gesto locationInView:self.pageView];
        CGFloat objetivo = self.scrollView.minimumZoomScale * 2.4;
        CGSize tam = CGSizeMake(self.scrollView.bounds.size.width / objetivo,
                                self.scrollView.bounds.size.height / objetivo);
        CGRect rect = CGRectMake(p.x - tam.width / 2, p.y - tam.height / 2,
                                 tam.width, tam.height);
        [self.scrollView zoomToRect:rect animated:YES];
    } else {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.pageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerContent];
}

#pragma mark - IRReader

- (BOOL)shouldInvert {
    return [IRTheme shared].readingInverts;
}

- (void)saveProgressNow {
    if (!self.document || !self.pdf) return;
    IRProgress *p = self.document.progress;
    p.page = self.pageIndex + 1;
    p.pageCount = self.pageCount;
    p.zoom = (self.fitScale > 0) ? (self.scrollView.zoomScale / self.fitScale) : 1;
    p.offset = [self normalizedOffset];
    p.finished = (self.pageCount > 0 && self.pageIndex + 1 >= self.pageCount);
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    return [NSString stringWithFormat:@"Pág. %ld de %ld", (long)(self.pageIndex + 1), (long)self.pageCount];
}

- (NSInteger)pageCount { return self.pageCount; }
- (NSInteger)currentPage { return self.pageIndex + 1; }

- (void)goToPage:(NSInteger)page {
    if (!self.pdf) return;
    NSInteger indice = MAX(1, MIN(self.pageCount, page)) - 1;
    if (indice == self.pageIndex && self.pageView) return;
    self.pageIndex = indice;
    [self saveProgressNow];
    [UIView animateWithDuration:0.12 animations:^{
        self.pageView.alpha = 0;
    } completion:^(BOOL finished) {
        [self showPageAtIndex:indice restorePosition:NO];
        self.pageView.alpha = 0;
        [UIView animateWithDuration:0.16 animations:^{
            self.pageView.alpha = 1;
        }];
    }];
}

- (NSArray<IRTOCItem *> *)tableOfContents { return self.outline ?: @[]; }

- (void)jumpToTOCItem:(IRTOCItem *)item {
    if (!item) return;
    [self goToPage:item.page];
}

- (BOOL)supportsBookmarks { return YES; }

- (void)addBookmarkWithNote:(NSString *)note {
    IRBookmark *b = [IRBookmark bookmarkWithPage:self.pageIndex + 1
                                           index:self.pageIndex
                                          anchor:@""
                                           label:[self pageLabel]
                                            note:note ?: @""];
    [self.document.bookmarks addObject:b];
    [[IRLibrary shared] save];
    [IRToast showIn:self.view message:@"Marcador guardado"];
}

- (BOOL)supportsSearch { return NO; }

- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *))completion {
    if (completion) completion(@[]);
}

- (void)jumpToSearchResult:(IRSearchResult *)result { }

- (void)applyDisplaySettings {
    self.view.backgroundColor = [IRTheme shared].readingBackground;
    self.scrollView.backgroundColor = [IRTheme shared].readingBackground;
    if (self.pageView) self.pageView.inverts = [self shouldInvert];
}

- (BOOL)isPaginated { return YES; }

@end
