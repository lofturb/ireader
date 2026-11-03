#import "IRComicReaderViewController.h"
#import "IRArchive.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRIcons.h"
#import "IRDialog.h"

@interface IRComicReaderViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *entries;
@property (nonatomic, assign) NSInteger pageIndex;
@property (nonatomic, assign) CGFloat fitZoom;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL didInitialLayout;

@end

@implementation IRComicReaderViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _pageIndex = 0;
        _entries = [NSMutableArray array];
        _fitZoom = 1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.readingBackground;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.minimumZoomScale = 1;
    self.scrollView.maximumZoomScale = 5;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.scrollView.bouncesZoom = YES;
    [self.view addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.imageView];
    self.scrollView.contentSize = self.view.bounds.size;

    UISwipeGestureRecognizer *izquierda = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(swipeIzquierda:)];
    izquierda.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.scrollView addGestureRecognizer:izquierda];

    UISwipeGestureRecognizer *derecha = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(swipeDerecha:)];
    derecha.direction = UISwipeGestureRecognizerDirectionRight;
    [self.scrollView addGestureRecognizer:derecha];

    UITapGestureRecognizer *doble = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                           action:@selector(doubleTapped:)];
    doble.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doble];

    self.loadingLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    self.loadingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.loadingLabel.font = tema.fontBody;
    self.loadingLabel.textColor = tema.readingText;
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    self.loadingLabel.text = @"Preparando cómic...";
    [self.view addSubview:self.loadingLabel];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = tema.fontBody;
    self.errorLabel.textColor = tema.readingText;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification"
                                               object:nil];

    [self enumerateImages];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.loadingLabel.frame = self.view.bounds;
    self.errorLabel.frame = CGRectInset(self.view.bounds, 40, 80);

    if (!self.loaded || self.view.bounds.size.width < 10) return;
    if (!self.didInitialLayout) {
        self.didInitialLayout = YES;
        [self fitImage];
        [self restoreZoom];
    } else {
        [self refitKeepingZoom];
    }
}

#pragma mark - Archivo

- (void)enumerateImages {
    NSString *ruta = self.document.path;
    __weak typeof(self) debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSArray *lista = [IRArchive listEntriesAtPath:ruta error:&error];
        NSMutableArray *imagenes = [NSMutableArray array];
        for (NSDictionary *e in lista) {
            if ([e[@"isDirectory"] boolValue]) continue;
            NSString *nombre = e[@"name"];
            if ([nombre hasPrefix:@"__MACOSX"]) continue;
            if (nombre.lastPathComponent.length > 0 &&
                [nombre.lastPathComponent hasPrefix:@"."]) continue;
            if ([IRUtils isImagePath:nombre]) [imagenes addObject:e];
        }
        [imagenes sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [IRUtils naturalCompare:a[@"name"] with:b[@"name"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(debil) fuerte = debil;
            if (!fuerte) return;
            if (!imagenes.count) {
                [fuerte fail:@"No hay imágenes en este cómic."];
                return;
            }
            [fuerte.entries setArray:imagenes];
            fuerte.pageIndex = MAX(0, MIN((NSInteger)imagenes.count - 1,
                                         fuerte.document.progress.page - 1));
            [fuerte loadPageAtIndex:fuerte.pageIndex];
        });
    });
}

- (void)fail:(NSString *)mensaje {
    self.loadingLabel.hidden = YES;
    self.errorLabel.text = mensaje;
    self.errorLabel.hidden = NO;
    if (self.onFailure) self.onFailure();
}

#pragma mark - Imagenes

- (void)loadPageAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.entries.count) return;
    self.pageIndex = index;
    NSString *ruta = self.document.path;
    NSDictionary *entrada = self.entries[(NSUInteger)index];
    self.loadingLabel.hidden = NO;
    self.loadingLabel.text = @"Cargando página...";
    __weak typeof(self) debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *datos = [IRArchive dataForEntry:entrada[@"name"] atPath:ruta error:NULL];
        UIImage *imagen = datos.length ? [IRUtils downsampleImageFromData:datos maxPixelSize:2048] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(debil) fuerte = debil;
            if (!fuerte) return;
            fuerte.loaded = (imagen != nil);
            [fuerte fitImage];
            if (!imagen) {
                fuerte.loadingLabel.hidden = NO;
                fuerte.loadingLabel.text = @"No se pudo cargar esta página.";
            } else {
                fuerte.loadingLabel.hidden = YES;
                fuerte.imageView.image = imagen;
                if (!fuerte.didInitialLayout) {
                    fuerte.didInitialLayout = YES;
                    [fuerte restoreZoom];
                }
            }
            fuerte.document.progress.page = fuerte.pageIndex + 1;
            fuerte.document.progress.pageCount = (NSInteger)MAX(1, fuerte.entries.count);
            fuerte.document.progress.index = fuerte.pageIndex;
        });
    });
}

- (void)fitImage {
    if (self.imageView.image) {
        self.scrollView.zoomScale = 1;
        self.scrollView.minimumZoomScale = 1;
        self.scrollView.maximumZoomScale = 5;
        self.scrollView.contentSize = self.view.bounds.size;
        self.imageView.frame = self.view.bounds;
    }
    [self centerContent];
}

- (void)refitKeepingZoom {
    CGFloat actual = self.scrollView.zoomScale;
    [self fitImage];
    if (self.loaded) {
        self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale,
                                        MAX(self.scrollView.minimumZoomScale, actual));
    }
    [self centerContent];
}

- (void)centerContent {
    CGSize contenido = self.scrollView.contentSize;
    CGSize visible = self.scrollView.bounds.size;
    CGFloat ix = MAX(0, (visible.width - contenido.width) / 2);
    CGFloat iy = MAX(0, (visible.height - contenido.height) / 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(iy, ix, iy, ix);
}

- (void)restoreZoom {
    if (!self.loaded) return;
    double zoom = self.document.progress.zoom;
    if (zoom > 1.01 && zoom < 5) {
        self.scrollView.zoomScale = zoom;
        [self centerContent];
    }
}

#pragma mark - Gestos

- (void)swipeIzquierda:(UISwipeGestureRecognizer *)gesto {
    if (self.pageIndex + 1 < (NSInteger)self.entries.count) {
        [self loadPageAtIndex:self.pageIndex + 1];
        [self saveProgressNow];
    }
}

- (void)swipeDerecha:(UISwipeGestureRecognizer *)gesto {
    if (self.scrollView.zoomScale > 1.05) return;
    if (self.pageIndex > 0) {
        [self loadPageAtIndex:self.pageIndex - 1];
        [self saveProgressNow];
    }
}

- (void)doubleTapped:(UITapGestureRecognizer *)gesto {
    if (self.scrollView.zoomScale <= 1.05) {
        self.scrollView.zoomScale = 2.4;
    } else {
        self.scrollView.zoomScale = 1;
    }
    [self centerContent];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerContent];
}

#pragma mark - IRReader

- (void)saveProgressNow {
    if (!self.document) return;
    IRProgress *p = self.document.progress;
    p.page = self.pageIndex + 1;
    p.pageCount = (NSInteger)MAX(1, self.entries.count);
    p.index = self.pageIndex;
    p.zoom = self.scrollView.zoomScale;
    p.ratio = ((double)(self.pageIndex + 1)) / ((double)MAX(1, self.entries.count));
    p.finished = (self.pageIndex + 1 >= (NSInteger)self.entries.count);
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    return [NSString stringWithFormat:@"Pág. %ld de %ld", (long)(self.pageIndex + 1),
            (long)MAX(1, self.entries.count)];
}

- (NSInteger)pageCount { return (NSInteger)MAX(1, self.entries.count); }
- (NSInteger)currentPage { return self.pageIndex + 1; }

- (void)goToPage:(NSInteger)page {
    NSInteger indice = MAX(0, MIN((NSInteger)self.entries.count - 1, page - 1));
    [self loadPageAtIndex:indice];
}

- (NSArray<IRTOCItem *> *)tableOfContents {
    NSMutableArray *salida = [NSMutableArray array];
    NSInteger i = 0;
    for (NSDictionary *e in self.entries) {
        NSString *nombre = e[@"name"];
        [salida addObject:[IRTOCItem itemWithTitle:[nombre lastPathComponent]
                                              page:i + 1 index:i anchor:@"" level:0]];
        i++;
    }
    return salida;
}

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
    if (self.loaded && self.didInitialLayout) [self refitKeepingZoom];
}

- (BOOL)isPaginated { return YES; }

@end
