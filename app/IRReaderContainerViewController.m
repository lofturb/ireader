#import "IRReaderContainerViewController.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRIcons.h"
#import "IRLibrary.h"
#import "IRDialog.h"

#import "IRPDFReaderViewController.h"
#import "IRTextReaderViewController.h"
#import "IRImageReaderViewController.h"
#import "IRComicReaderViewController.h"
#import "IRWebReaderViewController.h"
#import "IRHexReaderViewController.h"

// Los lectores comparten documento y aviso de fallo, aunque el protocolo
// IRReader solo cubra la navegacion.
@protocol IRReaderHosting <IRReader>
@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, copy) void (^onFailure)(void);
@end

@interface IRReaderContainerViewController () <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIViewController<IRReader> *reader;

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIButton *restoreButton;

@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *panelTitle;
@property (nonatomic, strong) UITableView *panelTable;
@property (nonatomic, strong) UIButton *panelClose;

@property (nonatomic, strong) NSArray *panelItems;
@property (nonatomic, assign) NSInteger panelKind;
@property (nonatomic, strong) NSTimer *tickTimer;

@property (nonatomic, assign) NSTimeInterval sesionInicio;
@property (nonatomic, assign) BOOL controlesVisibles;
@property (nonatomic, assign) BOOL cerrando;
@property (nonatomic, assign) BOOL didApplyInitialPage;

@end

@implementation IRReaderContainerViewController

- (instancetype)initWithDocument:(IRDocument *)document {
    self = [super init];
    if (self) {
        _document = document;
        _initialPage = 0;
        _controlesVisibles = YES;
        _sesionInicio = [NSDate date].timeIntervalSince1970;
        _panelKind = -1;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return !self.controlesVisibles;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return [IRTheme shared].dark ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.background;

    if (!self.document || self.document.isMissing) {
        [self showUnavailable];
        return;
    }

    [self buildTopBar];
    [self createReader];
    [self observeNotifications];
    [self refreshChrome];

    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                      target:self
                                                    selector:@selector(tick)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.didApplyInitialPage) return;
    self.didApplyInitialPage = YES;
    if (self.initialPage > 0 && self.reader) {
        [self.reader goToPage:self.initialPage];
        [self refreshChrome];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat barra = self.controlesVisibles ? [IRUtils statusBarHeight] + 46 : 0;

    self.topBar.frame = CGRectMake(0, 0, w, barra);
    self.backButton.frame = CGRectMake(4, barra - 44, 40, 40);
    self.menuButton.frame = CGRectMake(w - 44, barra - 44, 40, 40);
    self.pageLabel.frame = CGRectMake(w - 170, barra - 40, 122, 32);
    self.titleLabel.frame = CGRectMake(48, barra - 42, MAX(60, w - 48 - 176), 36);
    self.progressView.frame = CGRectMake(0, barra - 2, w, 2);

    self.reader.view.frame = CGRectMake(0, barra, w, h - barra);
    self.restoreButton.frame = CGRectMake(8, [IRUtils statusBarHeight] + 6, 40, 40);

    self.dimView.frame = self.view.bounds;
    CGFloat ancho = MIN(560, w - 60);
    CGFloat alto = MIN(h - 120, 620);
    self.panel.frame = CGRectMake((w - ancho) / 2, (h - alto) / 2, ancho, alto);
    self.panelTitle.frame = CGRectMake(20, 14, ancho - 100, 30);
    self.panelClose.frame = CGRectMake(ancho - 52, 10, 40, 40);
    self.panelTable.frame = CGRectMake(0, 56, ancho, alto - 56);
}

- (void)dealloc {
    [self.tickTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications {
    NSNotificationCenter *centro = [NSNotificationCenter defaultCenter];
    [centro addObserver:self selector:@selector(appWillResign:)
                   name:@"IRAppWillResignActiveNotification" object:nil];
    [centro addObserver:self selector:@selector(appWillResign:)
                   name:UIApplicationWillResignActiveNotification object:nil];
    [centro addObserver:self selector:@selector(appWillResign:)
                   name:UIApplicationDidEnterBackgroundNotification object:nil];
    [centro addObserver:self selector:@selector(appWillResign:)
                   name:UIApplicationWillTerminateNotification object:nil];
    [centro addObserver:self selector:@selector(themeChanged:)
                   name:IRThemeDidChangeNotification object:nil];
    [centro addObserver:self selector:@selector(memoryWarning:)
                   name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

#pragma mark - Barra superior

- (void)buildTopBar {
    IRTheme *tema = [IRTheme shared];

    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.98];
    [self.view addSubview:self.topBar];

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setImage:[IRIcons icon:IRGlyphChevronLeft size:22 color:tema.textPrimary]
                     forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(closeReader)
              forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.backButton];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = tema.fontHeadline;
    self.titleLabel.textColor = tema.textPrimary;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.topBar addSubview:self.titleLabel];

    self.pageLabel = [[UILabel alloc] init];
    self.pageLabel.font = tema.fontCaption;
    self.pageLabel.textColor = tema.textSecondary;
    self.pageLabel.textAlignment = NSTextAlignmentRight;
    self.pageLabel.adjustsFontSizeToFitWidth = YES;
    self.pageLabel.minimumScaleFactor = 0.7;
    [self.topBar addSubview:self.pageLabel];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.menuButton setImage:[IRIcons icon:IRGlyphMore size:20 color:tema.textPrimary]
                     forState:UIControlStateNormal];
    [self.menuButton addTarget:self action:@selector(menuTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.menuButton];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.progressTintColor = tema.accent;
    self.progressView.trackTintColor = tema.controlFill;
    [self.topBar addSubview:self.progressView];

    self.restoreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.restoreButton.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.92];
    self.restoreButton.layer.cornerRadius = 20;
    [self.restoreButton setImage:[IRIcons icon:IRGlyphChevronDown size:18 color:tema.textPrimary]
                        forState:UIControlStateNormal];
    [self.restoreButton addTarget:self action:@selector(showControls)
                 forControlEvents:UIControlEventTouchUpInside];
    self.restoreButton.hidden = YES;
    [self.view addSubview:self.restoreButton];
}

- (void)showControls {
    self.controlesVisibles = YES;
    self.restoreButton.hidden = YES;
    [self.view setNeedsLayout];
    [UIView animateWithDuration:0.18 animations:^{
        self.topBar.alpha = 1;
        self.topBar.hidden = NO;
        [self.view layoutIfNeeded];
    }];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)hideControls {
    self.controlesVisibles = NO;
    self.restoreButton.hidden = NO;
    [UIView animateWithDuration:0.18 animations:^{
        self.topBar.alpha = 0;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.topBar.hidden = YES;
    }];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)toggleControls {
    if (self.controlesVisibles) [self hideControls];
    else [self showControls];
}

- (void)refreshChrome {
    self.titleLabel.text = self.document.title.length ? self.document.title : @"Documento";
    self.pageLabel.text = [self.reader pageLabel];
    double fraccion = 0;
    if ([self.reader pageCount] > 1) {
        fraccion = ((double)([self.reader currentPage] - 1)) / ((double)([self.reader pageCount] - 1));
    }
    fraccion = MAX(0, MIN(1, fraccion));
    self.progressView.progress = fraccion;
}

#pragma mark - Lector

- (void)createReader {
    IRDocumentType tipo = self.document.type;
    UIViewController<IRReaderHosting> *lector = nil;

    switch (tipo) {
        case IRDocumentTypePDF:
            lector = (id)[[IRPDFReaderViewController alloc] init];
            break;
        case IRDocumentTypeText:
            lector = (id)[[IRTextReaderViewController alloc] init];
            break;
        case IRDocumentTypeImage:
            lector = (id)[[IRImageReaderViewController alloc] init];
            break;
        case IRDocumentTypeComic:
            lector = (id)[[IRComicReaderViewController alloc] init];
            break;
        case IRDocumentTypeEPUB:
        case IRDocumentTypeOffice:
        case IRDocumentTypeHTML:
        case IRDocumentTypeMedia:
            lector = (id)[[IRWebReaderViewController alloc] init];
            break;
        case IRDocumentTypeArchive:
        case IRDocumentTypeFolder:
        case IRDocumentTypeUnknown:
        default:
            lector = (id)[[IRHexReaderViewController alloc] init];
            break;
    }

    if (!lector) {
        [self showUnavailable];
        return;
    }

    lector.document = self.document;
    __weak typeof(self) debil = self;
    lector.onFailure = ^{
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        [fuerte refreshChrome];
    };

    [self addChildViewController:lector];
    lector.view.frame = self.view.bounds;
    lector.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:lector.view atIndex:0];
    [lector didMoveToParentViewController:self];
    self.reader = lector;

    [lector applyDisplaySettings];
    [self addToggleGesture];

    [self refreshChrome];
}

- (void)addToggleGesture {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(readerTapped:)];
    tap.numberOfTapsRequired = 1;
    tap.cancelsTouchesInView = NO;
    tap.delegate = (id)self;
    [self.reader.view addGestureRecognizer:tap];
}

- (void)readerTapped:(UITapGestureRecognizer *)gesto {
    if (!self.controlesVisibles) return;
    CGPoint punto = [gesto locationInView:self.view];
    if (punto.y <= [IRUtils statusBarHeight] + 50) return;
    [self toggleControls];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesto
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otro {
    return YES;
}

- (void)showUnavailable {
    IRTheme *tema = [IRTheme shared];
    UILabel *aviso = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 60, 120)];
    aviso.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    aviso.numberOfLines = 0;
    aviso.textAlignment = NSTextAlignmentCenter;
    aviso.font = tema.fontBody;
    aviso.textColor = tema.textSecondary;
    aviso.text = @"El archivo ya no esta disponible o su formato no se puede abrir.";
    [self.view addSubview:aviso];
}

#pragma mark - Menu

- (void)menuTapped:(UIButton *)sender {
    NSMutableArray *acciones = [NSMutableArray array];

    [acciones addObject:[IRDialogAction actionWithTitle:@"Indice"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self showTOC]; }]];

    [acciones addObject:[IRDialogAction actionWithTitle:@"Marcadores y notas"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self showBookmarks]; }]];

    if ([self.reader supportsSearch]) {
        [acciones addObject:[IRDialogAction actionWithTitle:@"Buscar en el documento"
                                                      style:IRDialogActionStyleDefault
                                                    handler:^{ [self showSearch]; }]];
    }

    [acciones addObject:[IRDialogAction actionWithTitle:@"Ir a pagina"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self showGoToPage]; }]];

    [acciones addObject:[IRDialogAction actionWithTitle:@"Ajustes de lectura"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self showReadingSettings]; }]];

    [acciones addObject:[IRDialogAction actionWithTitle:@"Informacion del documento"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self showInfo]; }]];

    [acciones addObject:[IRDialogAction actionWithTitle:@"Ocultar controles"
                                                  style:IRDialogActionStyleCancel
                                                handler:^{ [self hideControls]; }]];

    [IRDialog showSheetIn:self title:self.document.title actions:acciones];
}

- (void)showTOC {
    NSArray *items = [self.reader tableOfContents];
    if (!items.count) {
        [IRToast showIn:self.view message:@"Este documento no tiene indice."];
        return;
    }
    self.panelItems = items;
    self.panelKind = 0;
    [self showPanelWithTitle:@"Indice"];
}

- (void)showBookmarks {
    NSMutableArray *acciones = [NSMutableArray array];
    if ([self.reader supportsBookmarks]) {
        [acciones addObject:[IRDialogAction actionWithTitle:@"Anadir marcador en esta pagina"
                                                      style:IRDialogActionStyleDefault
                                                    handler:^{ [self promptBookmark]; }]];
    }
    [acciones addObject:[IRDialogAction actionWithTitle:@"Ver marcadores"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{ [self listBookmarks]; }]];
    [acciones addObject:[IRDialogAction actionWithTitle:@"Cancelar"
                                                  style:IRDialogActionStyleCancel
                                                handler:nil]];
    [IRDialog showSheetIn:self title:@"Marcadores" actions:acciones];
}

- (void)promptBookmark {
    __weak typeof(self) debil = self;
    [IRDialog showPromptIn:self
                     title:@"Nuevo marcador"
                   message:[self.reader pageLabel]
               placeholder:@"Nota (opcional)"
                      text:@""
                   handler:^(NSString *texto) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        [fuerte.reader addBookmarkWithNote:texto ?: @""];
        [[IRLibrary shared] save];
    }];
}

- (void)listBookmarks {
    NSArray *marcas = self.document.bookmarks;
    if (!marcas.count) {
        [IRToast showIn:self.view message:@"Todavia no hay marcadores."];
        return;
    }
    self.panelItems = marcas;
    self.panelKind = 1;
    [self showPanelWithTitle:@"Marcadores y notas"];
}

- (void)showSearch {
    __weak typeof(self) debil = self;
    [IRDialog showPromptIn:self
                     title:@"Buscar"
                   message:@"Escribe al menos dos caracteres."
               placeholder:@"Texto a buscar"
                      text:@""
                   handler:^(NSString *texto) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        NSString *consulta = [texto stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (consulta.length < 2) {
            [IRToast showIn:fuerte.view message:@"La busqueda es demasiado corta."];
            return;
        }
        [fuerte.searchReaderWithQuery:consulta];
    }];
}

- (void)searchReaderWithQuery:(NSString *)consulta {
    IRHUD *hud = [IRHUD showIn:self.view title:@"Buscando..." cancel:nil];
    __weak typeof(self) debil = self;
    [self.reader search:consulta completion:^(NSArray<IRSearchResult *> *resultados) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        [hud hide];
        if (!resultados.count) {
            [IRToast showIn:fuerte.view message:@"Sin resultados."];
            return;
        }
        fuerte.panelItems = resultados;
        fuerte.panelKind = 2;
        [fuerte showPanelWithTitle:
            [NSString stringWithFormat:@"%lu resultados", (unsigned long)resultados.count]];
    }];
}

#pragma mark - Panel

- (void)buildPanelIfNeeded {
    if (self.panel) return;
    IRTheme *tema = [IRTheme shared];

    self.dimView = [[UIView alloc] init];
    self.dimView.backgroundColor = tema.overlay;
    self.dimView.alpha = 0;
    self.dimView.hidden = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(hidePanel)];
    [self.dimView addGestureRecognizer:tap];
    [self.view addSubview:self.dimView];

    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = tema.cardBackground;
    self.panel.layer.cornerRadius = tema.largeCornerRadius;
    self.panel.clipsToBounds = YES;
    self.panel.alpha = 0;
    self.panel.hidden = YES;
    [self.view addSubview:self.panel];

    self.panelTitle = [[UILabel alloc] init];
    self.panelTitle.font = tema.fontHeadline;
    self.panelTitle.textColor = tema.textPrimary;
    [self.panel addSubview:self.panelTitle];

    self.panelClose = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.panelClose setImage:[IRIcons icon:IRGlyphClose size:18 color:tema.textSecondary]
                     forState:UIControlStateNormal];
    [self.panelClose addTarget:self action:@selector(hidePanel)
              forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.panelClose];

    self.panelTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.panelTable.dataSource = self;
    self.panelTable.delegate = self;
    self.panelTable.backgroundColor = tema.cardBackground;
    self.panelTable.separatorColor = tema.separator;
    self.panelTable.rowHeight = 52;
    self.panelTable.tableFooterView = [[UIView alloc] init];
    [self.panel addSubview:self.panelTable];
}

- (void)showPanelWithTitle:(NSString *)titulo {
    [self buildPanelIfNeeded];
    self.panelTitle.text = titulo;
    [self.panelTable reloadData];
    self.dimView.hidden = NO;
    self.panel.hidden = NO;
    [self.view bringSubviewToFront:self.dimView];
    [self.view bringSubviewToFront:self.panel];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:0.18 animations:^{
        self.dimView.alpha = 1;
        self.panel.alpha = 1;
    }];
}

- (void)hidePanel {
    [UIView animateWithDuration:0.16 animations:^{
        self.dimView.alpha = 0;
        self.panel.alpha = 0;
    } completion:^(BOOL finished) {
        self.dimView.hidden = YES;
        self.panel.hidden = YES;
        self.panelKind = -1;
        self.panelItems = nil;
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.panelItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identificador = @"IRReaderPanelCell";
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:identificador];
    }
    IRTheme *tema = [IRTheme shared];
    celda.backgroundColor = tema.cardBackground;
    celda.textLabel.textColor = tema.textPrimary;
    celda.textLabel.font = tema.fontBody;
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.font = tema.fontCaption;

    id item = self.panelItems[(NSUInteger)indexPath.row];
    NSString *detalle = @"";

    if (self.panelKind == 0 && [item isKindOfClass:[IRTOCItem class]]) {
        IRTOCItem *e = item;
        celda.textLabel.text = e.title.length ? e.title : @"Sin titulo";
        celda.indentationLevel = MIN(3, MAX(0, e.level));
        detalle = [NSString stringWithFormat:@"Pagina %ld", (long)e.page];
    } else if (self.panelKind == 1 && [item isKindOfClass:[IRBookmark class]]) {
        IRBookmark *b = item;
        celda.textLabel.text = b.note.length ? b.note : (b.label.length ? b.label : @"Marcador");
        detalle = [NSString stringWithFormat:@"Pagina %ld  ·  %@",
                   (long)b.page, [IRUtils dateString:b.createdAt]];
        celda.indentationLevel = 0;
    } else if (self.panelKind == 2 && [item isKindOfClass:[IRSearchResult class]]) {
        IRSearchResult *r = item;
        celda.textLabel.text = r.snippet.length ? r.snippet : r.quote;
        detalle = [NSString stringWithFormat:@"Pagina %ld", (long)r.page];
        celda.indentationLevel = 0;
    }
    celda.detailTextLabel.text = detalle;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id item = self.panelItems[(NSUInteger)indexPath.row];

    if (self.panelKind == 0 && [item isKindOfClass:[IRTOCItem class]]) {
        [self.reader jumpToTOCItem:item];
    } else if (self.panelKind == 1 && [item isKindOfClass:[IRBookmark class]]) {
        IRBookmark *b = item;
        [self.reader goToPage:b.page];
    } else if (self.panelKind == 2 && [item isKindOfClass:[IRSearchResult class]]) {
        [self.reader jumpToSearchResult:item];
    }
    [self hidePanel];
    [self refreshChrome];
}

#pragma mark - Acciones

- (void)showGoToPage {
    NSInteger total = [self.reader pageCount];
    __weak typeof(self) debil = self;
    [IRDialog showPromptIn:self
                     title:@"Ir a pagina"
                   message:[NSString stringWithFormat:@"Pagina actual %ld de %ld",
                            (long)[self.reader currentPage], (long)total]
               placeholder:@"Numero de pagina"
                      text:[NSString stringWithFormat:@"%ld", (long)[self.reader currentPage]]
                   handler:^(NSString *texto) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        NSInteger pagina = (NSInteger)[texto integerValue];
        if (pagina < 1 || pagina > total) {
            [IRToast showIn:fuerte.view message:@"Esa pagina no existe."];
            return;
        }
        [fuerte.reader goToPage:pagina];
        [fuerte refreshChrome];
    }];
}

- (void)showReadingSettings {
    NSMutableArray *acciones = [NSMutableArray array];
    NSArray *titulos = @[@"Original (tal cual es)", @"Papel", @"Sepia", @"Noche", @"Negro"];
    IRReadingTheme actual = [IRSettings shared].readingTheme;

    for (NSInteger i = 0; i < (NSInteger)titulos.count; i++) {
        IRDialogActionStyle estilo = (i == (NSInteger)actual)
            ? IRDialogActionStyleSelected : IRDialogActionStyleDefault;
        [acciones addObject:[IRDialogAction actionWithTitle:titulos[(NSUInteger)i]
                                                      style:estilo
                                                    handler:^{
            [IRSettings shared].readingTheme = (IRReadingTheme)i;
            [[IRSettings shared] save];
            [IRTheme shared].readingTheme = (IRReadingTheme)i;
            [self.reader applyDisplaySettings];
            [self applyChromeTheme];
        }]];
    }
    [acciones addObject:[IRDialogAction actionWithTitle:@"Cancelar"
                                                  style:IRDialogActionStyleCancel
                                                handler:nil]];
    [IRDialog showSheetIn:self title:@"Tema de lectura" actions:acciones];
}

- (void)showInfo {
    IRDocument *doc = self.document;
    NSMutableString *texto = [NSMutableString string];
    [texto appendFormat:@"%@\n", doc.title.length ? doc.title : @"Sin titulo"];
    if (doc.author.length) [texto appendFormat:@"%@\n", doc.author];
    [texto appendFormat:@"\nTipo: %@", [IRUtils typeName:doc.type]];
    [texto appendFormat:@"\nTamano: %@", [IRUtils fileSizeString:doc.fileSize]];
    [texto appendFormat:@"\nAnadido: %@", [IRUtils dateString:doc.addedAt]];
    [texto appendFormat:@"\n\n%@", [self.reader pageLabel]];
    if (doc.collections.count) {
        [texto appendFormat:@"\n\nColecciones: %@", [doc.collections componentsJoinedByString:@", "]];
    }
    [IRDialog showAlertIn:self title:@"Documento" message:texto];
}

- (void)applyChromeTheme {
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.background;
    self.topBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.98];
    self.titleLabel.textColor = tema.textPrimary;
    self.pageLabel.textColor = tema.textSecondary;
    self.progressView.progressTintColor = tema.accent;
    self.progressView.trackTintColor = tema.controlFill;
    self.panel.backgroundColor = tema.cardBackground;
    self.panelTitle.textColor = tema.textPrimary;
    self.panelTable.backgroundColor = tema.cardBackground;
    self.panelTable.separatorColor = tema.separator;
    self.dimView.backgroundColor = tema.overlay;
    [self.panelTable reloadData];
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Progreso

- (void)tick {
    if (!self.reader) return;
    [self refreshChrome];
    NSTimeInterval ahora = [NSDate date].timeIntervalSince1970;
    if (ahora - self.sesionInicio >= 30) {
        self.document.readingSeconds += (ahora - self.sesionInicio);
        self.sesionInicio = ahora;
    }
}

- (void)saveProgress {
    if (!self.reader || !self.document) return;
    [self.reader saveProgressNow];
    NSTimeInterval ahora = [NSDate date].timeIntervalSince1970;
    if (ahora > self.sesionInicio) {
        self.document.readingSeconds += (ahora - self.sesionInicio);
        self.sesionInicio = ahora;
    }
    self.document.lastOpenedAt = [NSDate date];
    [[IRLibrary shared] save];
}

- (void)appWillResign:(NSNotification *)nota {
    [self saveProgress];
}

- (void)memoryWarning:(NSNotification *)nota {
    [self saveProgress];
    if (self.panel.hidden) {
        self.panelTable = nil;
        self.panel = nil;
        self.dimView = nil;
    }
}

- (void)themeChanged:(NSNotification *)nota {
    [self applyChromeTheme];
    [self.reader applyDisplaySettings];
}

- (void)closeReader {
    if (self.cerrando) return;
    self.cerrando = YES;
    [self saveProgress];
    [self.tickTimer invalidate];
    self.tickTimer = nil;
    void (^aviso)(void) = self.onClose;
    [self dismissViewControllerAnimated:YES completion:^{
        if (aviso) aviso();
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgress];
}

@end
