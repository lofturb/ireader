#import "IRPDFReaderViewController.h"
#import "IRPDFPageView.h"
#import "IRPDFOutline.h"
#import "IRPDFThumbnails.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"

// Dos formas de leer un PDF:
//   - Vertical (por defecto): las paginas se apilan y se lee bajando, como un
//     flujo continuo. Solo se crean las paginas cercanas a la pantalla.
//   - Horizontal: una pagina a la vez, con gestos hacia los lados.
@interface IRPDFReaderViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *pagesContainer;
@property (nonatomic, strong) IRPDFPageView *pageView;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, IRPDFPageView *> *pageViews;
@property (nonatomic, strong) NSMutableArray<NSValue *> *pageFrames;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) NSArray<IRTOCItem *> *outline;
@property (nonatomic, strong) IRPDFThumbnails *thumbnails;
@property (nonatomic, assign) CGPDFDocumentRef pdf;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, assign) NSInteger pageCount;
@property (nonatomic, assign) CGFloat fitScale;
@property (nonatomic, assign) BOOL unlocked;
@property (nonatomic, assign) BOOL didInitialLayout;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL aplicandoZoom;
@property (nonatomic, assign) BOOL restaurandoPosicion;
// Queda activo hasta que la vista aparece: ahi se vuelve a aplicar la posicion
// guardada con el tamano definitivo de la pantalla.
@property (nonatomic, assign) BOOL pendingRestore;

- (void)loadDocument;
- (void)failWithMessage:(NSString *)mensaje;
- (void)requestPassword;
- (BOOL)shouldInvert;
- (void)applyScrollLock;
- (void)enforceScrollLock;
- (void)applySavedPosition;
- (void)showPageAtIndex:(NSInteger)index restorePosition:(BOOL)restore;

- (CGPoint)saveStateBeforeRelayout;
- (void)restoreStateAfterRelayout:(CGPoint)estado;

// Modo vertical
- (void)rebuildPageFrames;
- (void)updateVisiblePages;
- (NSInteger)pageIndexAtCurrentPosition;
- (void)scrollToPageVertically:(NSInteger)index animated:(BOOL)animated;
- (CGRect)frameForPage:(NSInteger)index;

// Modo horizontal
- (void)configurePageForDisplay;
- (void)adjustForSizeChange;
- (void)centerContent;
- (CGPoint)normalizedOffset;
- (void)restoreNormalizedOffset:(CGPoint)normalizado;

@end

@implementation IRPDFReaderViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _pageIndex = 0;
        _fitScale = 1;
        _outline = @[];
        _pageViews = [NSMutableDictionary dictionary];
        _pageFrames = [NSMutableArray array];
        _scrollDirection = [IRSettings shared].pdfScrollDirection;
    }
    return self;
}

- (void)dealloc {
    if (_pdf) CGPDFDocumentRelease(_pdf);
}

- (BOOL)verticalMode {
    return self.scrollDirection == IRPDFScrollDirectionVertical;
}

- (void)setScrollDirection:(IRPDFScrollDirection)scrollDirection {
    if (_scrollDirection == scrollDirection) return;
    if (self.isViewLoaded) [self saveProgressNow];
    _scrollDirection = scrollDirection;
    if (self.isViewLoaded) [self refreshLayoutForDirection];
}

- (void)refreshLayoutForDirection {
    NSInteger pagina = self.pageIndex;
    if (self.verticalMode) {
        [self.pageView removeFromSuperview];
        self.pageView = nil;
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.pagingEnabled = NO;
        self.scrollView.directionalLockEnabled = YES;
    } else {
        for (IRPDFPageView *v in self.pageViews.allValues) [v removeFromSuperview];
        [self.pageViews removeAllObjects];
        [self.pageFrames removeAllObjects];
        [self.pagesContainer removeFromSuperview];
        self.pagesContainer = nil;
        self.scrollView.contentInset = UIEdgeInsetsZero;
    }
    [self showPageAtIndex:pagina restorePosition:YES];
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
    self.scrollView.maximumZoomScale = 4;
    self.scrollView.minimumZoomScale = 1;
    self.scrollView.directionalLockEnabled = YES;
    [self.view addSubview:self.scrollView];
    [self applyScrollLock];

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

#pragma mark - Disposicion

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.errorLabel.frame = CGRectInset(self.view.bounds, 40, 80);
    if (!self.pdf || self.failed) return;

    if (self.verticalMode) {
        CGFloat anchoAnterior = self.pagesContainer.bounds.size.width;
        CGFloat ancho = self.scrollView.bounds.size.width;
        if (self.pageFrames.count == 0 || fabs(ancho - anchoAnterior) > 0.5) {
            CGPoint guardado = [self saveStateBeforeRelayout];
            [self rebuildPageFrames];
            [self restoreStateAfterRelayout:guardado];
        }
        [self updateVisiblePages];
    } else if (self.pageView) {
        BOOL primero = !self.didInitialLayout;
        self.didInitialLayout = YES;
        if (primero) {
            [self configurePageForDisplay];
            if (self.pendingRestore) [self applySavedPosition];
        } else {
            [self adjustForSizeChange];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.pendingRestore || !self.pdf) return;
    self.pendingRestore = NO;
    // Ultima pasada con la vista ya visible y el tamano definitivo.
    [self applySavedPosition];
    if (self.verticalMode) [self updateVisiblePages];
    [self applyDisplaySettings];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

- (CGRect)frameForPage:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.pageFrames.count) return CGRectZero;
    return [self.pageFrames[(NSUInteger)index] CGRectValue];
}

- (void)rebuildPageFrames {
    [self.pageFrames removeAllObjects];
    CGFloat ancho = MAX(160.0, self.scrollView.bounds.size.width);
    if (self.scrollView.zoomScale > 1.001) {
        // Al recolocar se vuelve a la escala de ajuste para no perder el sitio.
        self.scrollView.zoomScale = 1;
    }
    self.pagesContainer.frame = CGRectMake(0, 0, ancho, 1);
    [self.scrollView addSubview:self.pagesContainer];

    CGFloat hueco = 16;
    CGFloat y = 0;
    for (NSInteger i = 0; i < self.pageCount; i++) {
        CGSize tam = [IRPDFPageView pageSizeForDocument:self.pdf page:i + 1];
        CGFloat alto = (tam.width > 1) ? ancho * (tam.height / tam.width) : ancho * 1.4;
        alto = MAX(120.0, alto);
        [self.pageFrames addObject:[NSValue valueWithCGRect:CGRectMake(0, y, ancho, alto)]];
        y += alto + hueco;
    }
    self.pagesContainer.frame = CGRectMake(0, 0, ancho, MAX(1, y - hueco));
    self.scrollView.contentSize = self.pagesContainer.bounds.size;

    for (NSNumber *clave in self.pageViews) {
        IRPDFPageView *v = self.pageViews[clave];
        CGRect marco = [self frameForPage:clave.integerValue];
        if (!CGRectIsEmpty(marco)) v.frame = marco;
    }
}

- (CGPoint)saveStateBeforeRelayout {
    NSInteger pagina = [self pageIndexAtCurrentPosition];
    CGRect marco = [self frameForPage:pagina];
    CGFloat escala = MAX(0.0001, self.scrollView.zoomScale);
    CGFloat arriba = self.scrollView.contentOffset.y / escala;
    CGFloat proporcion = (marco.size.height > 1) ? (arriba - marco.origin.y) / marco.size.height : 0;
    return CGPointMake((CGFloat)pagina, MAX(0, MIN(1, proporcion)));
}

- (void)restoreStateAfterRelayout:(CGPoint)estado {
    NSInteger pagina = (NSInteger)estado.x;
    CGRect marco = [self frameForPage:pagina];
    if (CGRectIsEmpty(marco)) return;
    CGFloat y = marco.origin.y + estado.y * marco.size.height;
    self.scrollView.contentOffset = CGPointMake(0, y);
    self.pageIndex = pagina;
}

- (void)updateVisiblePages {
    if (!self.verticalMode || self.pageFrames.count == 0) return;
    CGFloat escala = MAX(0.0001, self.scrollView.zoomScale);
    CGRect visible = self.scrollView.bounds;
    visible.origin = CGPointMake(self.scrollView.contentOffset.x / escala,
                                 self.scrollView.contentOffset.y / escala);
    visible.size = CGSizeMake(visible.size.width / escala, visible.size.height / escala);
    CGRect rango = CGRectInset(visible, 0, -visible.size.height * 1.5);

    NSMutableSet *necesarias = [NSMutableSet set];
    for (NSInteger i = 0; i < (NSInteger)self.pageFrames.count; i++) {
        if (CGRectIntersectsRect([self frameForPage:i], rango)) [necesarias addObject:@(i)];
    }

    for (NSNumber *clave in [self.pageViews.allKeys copy]) {
        if (![necesarias containsObject:clave]) {
            [self.pageViews[clave] removeFromSuperview];
            [self.pageViews removeObjectForKey:clave];
        }
    }
    for (NSNumber *clave in necesarias) {
        if (self.pageViews[clave]) continue;
        NSInteger i = clave.integerValue;
        CGRect marco = [self frameForPage:i];
        if (CGRectIsEmpty(marco)) continue;
        IRPDFPageView *v = [[IRPDFPageView alloc] initWithDocument:self.pdf
                                                             page:i + 1
                                                          inverts:[self shouldInvert]];
        v.frame = marco;
        [self.pagesContainer addSubview:v];
        self.pageViews[clave] = v;
    }

    NSInteger actual = [self pageIndexAtCurrentPosition];
    if (!self.restaurandoPosicion && actual != self.pageIndex) {
        self.pageIndex = actual;
    }
}

- (NSInteger)pageIndexAtCurrentPosition {
    if (self.pageFrames.count == 0) return 0;
    CGFloat escala = MAX(0.0001, self.scrollView.zoomScale);
    // La pagina actual es la que ocupa la parte superior visible. Usar el
    // centro o un porcentaje alto hacia que la posicion guardada saltara de
    // pagina al reabrir el documento.
    CGFloat y = (self.scrollView.contentOffset.y / escala) + 1.0;
    for (NSInteger i = 0; i < (NSInteger)self.pageFrames.count; i++) {
        CGRect marco = [self frameForPage:i];
        if (y >= marco.origin.y && y < CGRectGetMaxY(marco)) return i;
    }
    return (y <= 0) ? 0 : MAX(0, (NSInteger)self.pageFrames.count - 1);
}

- (void)scrollToPageVertically:(NSInteger)index animated:(BOOL)animated {
    CGRect marco = [self frameForPage:index];
    if (CGRectIsEmpty(marco)) return;
    CGPoint destino = CGPointMake(0, marco.origin.y * MAX(1.0, self.scrollView.zoomScale));
    CGFloat maxY = MAX(0, self.scrollView.contentSize.height - self.scrollView.bounds.size.height);
    destino.y = MAX(0, MIN(maxY, destino.y));
    [self.scrollView setContentOffset:destino animated:animated];
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
    self.pendingRestore = restore;

    if (self.verticalMode) {
        self.restaurandoPosicion = YES;
        self.scrollView.zoomScale = 1;
        [self.pageViews removeAllObjects];
        [self.pagesContainer removeFromSuperview];
        self.pagesContainer = [[UIView alloc] init];
        self.pagesContainer.backgroundColor = [UIColor clearColor];
        [self.scrollView addSubview:self.pagesContainer];
        [self rebuildPageFrames];

        if (restore) {
            [self applySavedPosition];
        } else {
            [self scrollToPageVertically:self.pageIndex animated:NO];
        }
        [self updateVisiblePages];
        self.restaurandoPosicion = NO;
        [self applyDisplaySettings];
        return;
    }

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
        [self applySavedPosition];
    }
    [self applyDisplaySettings];
}

// Coloca la vista en la pagina y la parte de pagina guardadas. Se usa al
// abrir el documento y otra vez cuando la vista ya esta visible, para que un
// cambio de tamano durante la presentacion no mande al inicio o al final.
- (void)applySavedPosition {
    if (!self.pdf) return;
    IRProgress *p = self.document.progress;
    NSInteger pagina = MAX(0, MIN(self.pageCount - 1, p.page - 1));
    BOOL anterior = self.restaurandoPosicion;
    self.restaurandoPosicion = YES;
    self.pageIndex = pagina;

    if (self.verticalMode) {
        CGRect marco = [self frameForPage:pagina];
        if (!CGRectIsEmpty(marco)) {
            double factor = p.zoom;
            if (factor > 1.01 && factor < 6) {
                self.aplicandoZoom = YES;
                self.scrollView.zoomScale = MIN(4.0, MAX(1.0, factor));
                self.aplicandoZoom = NO;
            }
            // La pagina guardada manda: se restaura su parte proporcional. No
            // se usa el desplazamiento global porque puede caer en otra pagina
            // y mandar al principio o al final del documento.
            CGFloat proporcion = MAX(0.0, MIN(1.0, p.ratio));
            CGFloat y = marco.origin.y + proporcion * marco.size.height;
            CGFloat limite = MAX(0, self.scrollView.contentSize.height - self.scrollView.bounds.size.height);
            self.scrollView.contentOffset = CGPointMake(0,
                MAX(0, MIN(limite, y * MAX(1.0, self.scrollView.zoomScale))));
        }
    } else {
        if (self.pageView && self.pageView.pageNumber != pagina + 1) {
            [self.pageView removeFromSuperview];
            self.pageView = [[IRPDFPageView alloc] initWithDocument:self.pdf
                                                               page:pagina + 1
                                                            inverts:[self shouldInvert]];
            CGSize tam = self.pageView.pageSize;
            self.pageView.frame = CGRectMake(0, 0, tam.width, tam.height);
            [self.scrollView addSubview:self.pageView];
            [self configurePageForDisplay];
        }
        double factor = p.zoom;
        if (factor > 1.01 && factor < 6) {
            self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale,
                                            MAX(self.scrollView.minimumZoomScale,
                                                self.fitScale * factor));
            [self centerContent];
        }
        CGPoint guardado = p.offset;
        if (guardado.x > 0.001 || guardado.y > 0.001) {
            [self restoreNormalizedOffset:guardado];
        }
    }
    self.restaurandoPosicion = anterior;
}

- (void)failWithMessage:(NSString *)mensaje {
    self.failed = YES;
    self.errorLabel.text = mensaje;
    self.errorLabel.hidden = NO;
    [self.scrollView removeFromSuperview];
    [self.view addSubview:self.errorLabel];
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

#pragma mark - Modo horizontal

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
    // Si el tamano visible no cambio, no se toca el desplazamiento: abrir un
    // menu o mostrar la barra no debe recentrar la pagina.
    if (fabs(escala - self.fitScale) < 0.0005) return;
    CGPoint normalizado = [self normalizedOffset];
    self.fitScale = escala;
    self.scrollView.minimumZoomScale = escala;
    self.scrollView.maximumZoomScale = MAX(3.0, escala * 5.0);
    CGFloat objetivo = MAX(escala, MIN(self.scrollView.maximumZoomScale, escala * relativo));
    self.scrollView.zoomScale = objetivo;
    [self centerContent];
    [self restoreNormalizedOffset:normalizado];
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

#pragma mark - Gestos

- (void)swipeLeft:(UISwipeGestureRecognizer *)gesto {
    if (self.verticalMode) return;
    if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale * 1.06) return;
    if (self.pageIndex + 1 < self.pageCount) [self goToPage:self.pageIndex + 2];
}

- (void)swipeRight:(UISwipeGestureRecognizer *)gesto {
    if (self.verticalMode) return;
    if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale * 1.06) return;
    if (self.pageIndex > 0) [self goToPage:self.pageIndex];
}

- (void)doubleTapped:(UITapGestureRecognizer *)gesto {
    if (self.verticalMode) {
        if (self.scrollView.zoomScale > 1.02) {
            [self.scrollView setZoomScale:1 animated:YES];
        } else {
            CGPoint p = [gesto locationInView:self.pagesContainer];
            CGFloat objetivo = 2.2;
            CGSize tam = CGSizeMake(self.scrollView.bounds.size.width / objetivo,
                                    self.scrollView.bounds.size.height / objetivo);
            [self.scrollView zoomToRect:CGRectMake(p.x - tam.width / 2, p.y - tam.height / 2,
                                                   tam.width, tam.height) animated:YES];
        }
        return;
    }
    if (!self.pageView) return;
    if (self.scrollView.zoomScale <= self.scrollView.minimumZoomScale * 1.08) {
        CGPoint p = [gesto locationInView:self.pageView];
        CGFloat objetivo = self.scrollView.minimumZoomScale * 2.4;
        CGSize tam = CGSizeMake(self.scrollView.bounds.size.width / objetivo,
                                self.scrollView.bounds.size.height / objetivo);
        [self.scrollView zoomToRect:CGRectMake(p.x - tam.width / 2, p.y - tam.height / 2,
                                               tam.width, tam.height) animated:YES];
    } else {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.verticalMode ? self.pagesContainer : self.pageView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self enforceScrollLock];
    if (self.verticalMode) [self updateVisiblePages];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (self.verticalMode) {
        [self updateVisiblePages];
    } else {
        [self centerContent];
    }
}

#pragma mark - IRReader

- (BOOL)shouldInvert {
    return [IRTheme shared].readingInverts;
}

- (void)saveProgressNow {
    if (!self.document || !self.pdf) return;
    IRProgress *p = self.document.progress;
    p.pageCount = self.pageCount;

    if (self.verticalMode) {
        NSInteger idx = [self pageIndexAtCurrentPosition];
        CGRect marco = [self frameForPage:idx];
        CGFloat escala = MAX(0.0001, self.scrollView.zoomScale);
        CGFloat arriba = self.scrollView.contentOffset.y / escala;
        p.page = idx + 1;
        p.index = idx;
        p.ratio = (marco.size.height > 1)
            ? MAX(0, MIN(1, (arriba - marco.origin.y) / marco.size.height)) : 0;
        p.zoom = MAX(1.0, self.scrollView.zoomScale);
        p.offset = [self normalizedOffset];
        p.finished = (idx + 1 >= self.pageCount) && (p.ratio > 0.9);
    } else {
        p.page = self.pageIndex + 1;
        p.index = self.pageIndex;
        p.zoom = (self.fitScale > 0) ? (self.scrollView.zoomScale / self.fitScale) : 1;
        p.offset = [self normalizedOffset];
        p.ratio = 0;
        p.finished = (self.pageCount > 0 && self.pageIndex + 1 >= self.pageCount);
    }
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    return [NSString stringWithFormat:@"Pág. %ld de %ld",
            (long)(self.pageIndex + 1), (long)self.pageCount];
}

- (NSInteger)pageCount { return _pageCount; }
- (NSInteger)currentPage { return self.pageIndex + 1; }

- (void)goToPage:(NSInteger)page {
    if (!self.pdf) return;
    NSInteger indice = MAX(1, MIN(self.pageCount, page)) - 1;

    if (self.verticalMode) {
        if (indice == self.pageIndex && self.pageViews.count) return;
        [self saveProgressNow];
        self.pageIndex = indice;
        [self scrollToPageVertically:indice animated:YES];
        [self updateVisiblePages];
        return;
    }

    if (indice == self.pageIndex && self.pageView) return;
    [self saveProgressNow];
    self.pageIndex = indice;
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
    for (IRPDFPageView *v in self.pageViews.allValues) v.inverts = [self shouldInvert];
    [self applyScrollLock];
}

- (void)applyScrollLock {
    BOOL bloqueo = [IRSettings shared].lockScrollAxis;
    UIScrollView *sv = self.scrollView;
    if (!sv) return;
    sv.directionalLockEnabled = YES;
    // Sin rebote lateral: un gesto diagonal no debe arrastrar la pagina.
    sv.alwaysBounceHorizontal = NO;
    sv.alwaysBounceVertical = NO;
    if (bloqueo) [self enforceScrollLock];
}

- (void)enforceScrollLock {
    if (![IRSettings shared].lockScrollAxis) return;
    UIScrollView *sv = self.scrollView;
    if (!sv || sv.isZooming || sv.isZoomBouncing) return;
    CGPoint offset = sv.contentOffset;
    if (self.verticalMode) {
        // Al ampliar se permite mover lateralmente para ver los bordes.
        if (sv.zoomScale > 1.011) return;
        if (fabs(offset.x) < 0.5) return;
        offset.x = 0;
    } else {
        if (sv.zoomScale > sv.minimumZoomScale * 1.011) return;
        CGFloat y = -sv.contentInset.top;
        if (fabs(offset.y - y) < 0.5) return;
        offset.y = y;
    }
    sv.contentOffset = offset;
}

- (BOOL)isPaginated { return YES; }

@end
