#import "IRHexReaderViewController.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRIcons.h"
#import "IRDialog.h"

// Visor hexadecimal de solo lectura. Muestra el archivo como filas de 16 bytes
// con desplazamiento, hexadecimal y texto ASCII. Solo se lee una ventana
// acotada del archivo para no agotar la memoria del dispositivo.
@interface IRHexReaderViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIView *headerBar;
@property (nonatomic, strong) UILabel *offsetLabel;
@property (nonatomic, strong) UIButton *gotoButton;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, assign) NSUInteger totalRows;
@property (nonatomic, assign) NSUInteger rowsPerPage;
@property (nonatomic, assign) BOOL didRestore;

@end

@interface IRHexRowCell : UITableViewCell

- (void)configureWithBytes:(const uint8_t *)bytes
                     count:(NSUInteger)count
                    offset:(unsigned long long)offset;

@end

@implementation IRHexReaderViewController

static const NSUInteger kBytesPorFila = 16;
static const NSUInteger kMaxBytes = 16 * 1024 * 1024;
static const CGFloat kAltoFila = 20.0;

- (instancetype)init {
    self = [super init];
    if (self) {
        _rowsPerPage = 30;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].readingBackground;

    [self buildHeader];
    [self buildTable];
    [self openFile];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification"
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat barra = 40;

    self.headerBar.frame = CGRectMake(0, 0, w, barra);
    self.gotoButton.frame = CGRectMake(w - 84, 4, 76, 32);
    self.offsetLabel.frame = CGRectMake(12, 4, MAX(80, w - 108), 32);
    self.tableView.frame = CGRectMake(0, barra, w, MAX(0, h - barra));

    NSUInteger filas = (NSUInteger)MAX(1, floor((h - barra) / kAltoFila));
    if (filas != self.rowsPerPage) {
        self.rowsPerPage = filas;
    }
    if (!self.didRestore && self.data.length > 0) {
        self.didRestore = YES;
        [self.tableView layoutIfNeeded];
        [self restoreProgress];
    }
    [self updateOffsetLabel];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildHeader {
    IRTheme *tema = [IRTheme shared];

    self.headerBar = [[UIView alloc] init];
    self.headerBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.96];
    [self.view addSubview:self.headerBar];

    self.offsetLabel = [[UILabel alloc] init];
    self.offsetLabel.font = [tema fontMono:12];
    self.offsetLabel.textColor = tema.textSecondary;
    self.offsetLabel.textAlignment = NSTextAlignmentLeft;
    self.offsetLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.headerBar addSubview:self.offsetLabel];

    self.gotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.gotoButton.titleLabel.font = tema.fontSubhead;
    [self.gotoButton setTitle:@"Ir a..." forState:UIControlStateNormal];
    [self.gotoButton setTitleColor:tema.accent forState:UIControlStateNormal];
    [self.gotoButton addTarget:self action:@selector(gotoTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.headerBar addSubview:self.gotoButton];
}

- (void)buildTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = kAltoFila;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.indicatorStyle = [IRTheme shared].dark
        ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.view addSubview:self.tableView];
}

- (void)openFile {
    NSString *ruta = self.document.path;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (!ruta || ![fm fileExistsAtPath:ruta]) {
        [self showFailure:@"El archivo ya no esta disponible."];
        return;
    }

    NSDictionary *atributos = [fm attributesOfItemAtPath:ruta error:NULL];
    self.fileSize = [atributos fileSize];

    NSFileHandle *manejador = [NSFileHandle fileHandleForReadingAtPath:ruta];
    if (!manejador) {
        [self showFailure:@"No se pudo leer el archivo."];
        return;
    }

    NSUInteger aLeer = (NSUInteger)MIN((unsigned long long)kMaxBytes, self.fileSize);
    NSData *datos = nil;
    @try {
        datos = [manejador readDataOfLength:aLeer];
    } @catch (NSException *excepcion) {
        datos = nil;
    }
    [manejador closeFile];

    if (!datos) {
        [self showFailure:@"No se pudo leer el archivo."];
        return;
    }

    self.data = datos;
    self.totalRows = (datos.length + kBytesPorFila - 1) / kBytesPorFila;
    [self.tableView reloadData];

    if (self.fileSize > kMaxBytes) {
        [IRToast showIn:self.view
                message:[NSString stringWithFormat:@"Vista parcial: primeros %@ de %@.",
                         [IRUtils fileSizeString:kMaxBytes],
                         [IRUtils fileSizeString:self.fileSize]]];
    }
}

- (void)showFailure:(NSString *)mensaje {
    self.offsetLabel.text = mensaje;
    if (self.onFailure) self.onFailure();
}

- (void)restoreProgress {
    IRProgress *p = self.document.progress;
    if (!p) return;
    if (p.ratio > 0.0001 && self.totalRows > 0) {
        double fraccion = MAX(0, MIN(1, p.ratio));
        NSUInteger fila = (NSUInteger)floor(fraccion * (double)self.totalRows);
        CGFloat altoPagina = MAX(1, self.rowsPerPage * kAltoFila);
        NSInteger pagina = (NSInteger)(fila / MAX(1, self.rowsPerPage)) + 1;
        CGFloat y = (pagina - 1) * altoPagina;
        CGFloat maximo = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height);
        [self.tableView setContentOffset:CGPointMake(0, MAX(0, MIN(maximo, y))) animated:NO];
        return;
    }
    if (p.page > 0) {
        [self goToPage:p.page];
    }
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.totalRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identificador = @"IRHexRowCell";
    IRHexRowCell *celda = (IRHexRowCell *)[tableView dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[IRHexRowCell alloc] initWithStyle:UITableViewCellStyleDefault
                                    reuseIdentifier:identificador];
    }
    NSUInteger fila = (NSUInteger)indexPath.row;
    NSUInteger inicio = fila * kBytesPorFila;
    NSUInteger disponible = self.data.length > inicio ? self.data.length - inicio : 0;
    NSUInteger cuenta = MIN(kBytesPorFila, disponible);
    const uint8_t *bytes = (const uint8_t *)self.data.bytes + inicio;
    [celda configureWithBytes:bytes count:cuenta offset:(unsigned long long)inicio];
    return celda;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateOffsetLabel];
}

#pragma mark - Navegacion

- (NSInteger)pageCount {
    if (self.totalRows == 0) return 1;
    NSUInteger paginas = (self.totalRows + self.rowsPerPage - 1) / self.rowsPerPage;
    return (NSInteger)MAX(1, paginas);
}

- (NSInteger)currentPage {
    if (self.totalRows == 0) return 1;
    CGFloat altoPagina = MAX(1, self.rowsPerPage * kAltoFila);
    NSInteger pagina = (NSInteger)floor(self.tableView.contentOffset.y / altoPagina) + 1;
    return MAX(1, MIN([self pageCount], pagina));
}

- (void)goToPage:(NSInteger)page {
    NSInteger total = [self pageCount];
    NSInteger destino = MAX(1, MIN(total, page));
    CGFloat altoPagina = MAX(1, self.rowsPerPage * kAltoFila);
    CGFloat y = (destino - 1) * altoPagina;
    CGFloat maximo = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height);
    y = MAX(0, MIN(maximo, y));
    [self.tableView setContentOffset:CGPointMake(0, y) animated:NO];
    [self updateOffsetLabel];
}

- (void)updateOffsetLabel {
    if (self.data.length == 0) {
        self.offsetLabel.text = @"Archivo vacio";
        return;
    }
    NSUInteger fila = (NSUInteger)MAX(0, self.tableView.contentOffset.y / kAltoFila);
    unsigned long long inicio = (unsigned long long)fila * kBytesPorFila;
    unsigned long long fin = inicio + (unsigned long long)self.rowsPerPage * kBytesPorFila;
    if (fin > self.data.length) fin = self.data.length;
    self.offsetLabel.text = [NSString stringWithFormat:@"0x%08llX - 0x%08llX  ·  %@ de %@",
                             inicio, fin > 0 ? fin - 1 : 0,
                             [IRUtils fileSizeString:(unsigned long long)self.data.length],
                             [IRUtils fileSizeString:self.fileSize]];
}

- (void)gotoTapped:(UIButton *)sender {
    __weak typeof(self) debil = self;
    [IRDialog showPromptIn:self
                     title:@"Ir a posicion"
                   message:@"Escribe un desplazamiento en hexadecimal (0x1A00) o decimal."
               placeholder:@"0x00000000"
                      text:@"0x"
                   handler:^(NSString *texto) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        [fuerte jumpToText:texto];
    }];
}

- (void)jumpToText:(NSString *)texto {
    NSString *limpio = [[texto stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (limpio.length == 0) return;

    unsigned long long valor = 0;
    BOOL valido = NO;
    if ([limpio hasPrefix:@"0x"]) {
        NSScanner *escanner = [NSScanner scannerWithString:[limpio substringFromIndex:2]];
        valido = [escanner scanHexLongLong:&valor];
    } else {
        NSScanner *escanner = [NSScanner scannerWithString:limpio];
        valido = [escanner scanUnsignedLongLong:&valor];
    }
    if (!valido) {
        [IRToast showIn:self.view message:@"Esa posicion no es valida."];
        return;
    }
    unsigned long long limite = self.data.length;
    if (valor >= limite) {
        [IRToast showIn:self.view message:@"Esa posicion queda fuera del archivo."];
        return;
    }
    NSUInteger fila = (NSUInteger)(valor / kBytesPorFila);
    CGFloat y = fila * kAltoFila;
    CGFloat maximo = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height);
    y = MAX(0, MIN(maximo, y));
    [self.tableView setContentOffset:CGPointMake(0, y) animated:NO];
    [self updateOffsetLabel];
}

#pragma mark - IRReader

- (void)saveProgressNow {
    if (!self.document) return;
    IRProgress *p = self.document.progress;
    p.page = [self currentPage];
    p.pageCount = [self pageCount];
    NSUInteger fila = (NSUInteger)MAX(0, self.tableView.contentOffset.y / kAltoFila);
    p.ratio = self.totalRows > 0 ? MIN(1.0, (double)fila / (double)self.totalRows) : 0;
    p.finished = (fila + self.rowsPerPage >= self.totalRows);
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    return [NSString stringWithFormat:@"Pag. %ld de %ld",
            (long)[self currentPage], (long)[self pageCount]];
}

- (NSArray<IRTOCItem *> *)tableOfContents { return @[]; }
- (void)jumpToTOCItem:(IRTOCItem *)item { }

- (BOOL)supportsBookmarks { return YES; }

- (void)addBookmarkWithNote:(NSString *)note {
    IRBookmark *marca = [IRBookmark bookmarkWithPage:[self currentPage]
                                              index:0
                                             anchor:nil
                                              label:[self pageLabel]
                                               note:note ?: @""];
    [self.document.bookmarks addObject:marca];
    [[IRLibrary shared] save];
    [IRToast showIn:self.view message:@"Marcador guardado"];
}

- (BOOL)supportsSearch { return NO; }

- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *))completion {
    if (completion) completion(@[]);
}

- (void)jumpToSearchResult:(IRSearchResult *)result { }

- (void)applyDisplaySettings {
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.readingBackground;
    self.headerBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.96];
    self.offsetLabel.textColor = tema.textSecondary;
    [self.gotoButton setTitleColor:tema.accent forState:UIControlStateNormal];
    self.tableView.indicatorStyle = tema.dark
        ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tableView reloadData];
    [self updateOffsetLabel];
}

- (BOOL)isPaginated { return NO; }

@end

#pragma mark - Celda

@implementation IRHexRowCell {
    UILabel *_offset;
    UILabel *_hex;
    UILabel *_ascii;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _offset = [[UILabel alloc] init];
        _offset.font = [[IRTheme shared] fontMono:11];
        _offset.textColor = [IRTheme shared].textTertiary;
        _offset.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:_offset];

        _hex = [[UILabel alloc] init];
        _hex.font = [[IRTheme shared] fontMono:11];
        _hex.textColor = [IRTheme shared].textPrimary;
        [self.contentView addSubview:_hex];

        _ascii = [[UILabel alloc] init];
        _ascii.font = [[IRTheme shared] fontMono:11];
        _ascii.textColor = [IRTheme shared].textSecondary;
        [self.contentView addSubview:_ascii];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat x = 12;
    CGFloat anchoOffset = 78;
    CGFloat anchoHex = MIN(MAX(220, w * 0.46), 380);
    _offset.frame = CGRectMake(x, 0, anchoOffset, h);
    _hex.frame = CGRectMake(x + anchoOffset, 0, anchoHex, h);
    _ascii.frame = CGRectMake(x + anchoOffset + anchoHex + 10, 0,
                              MAX(40, w - (x + anchoOffset + anchoHex + 22)), h);
}

- (void)configureWithBytes:(const uint8_t *)bytes
                     count:(NSUInteger)count
                    offset:(unsigned long long)offset {
    _offset.text = [NSString stringWithFormat:@"%08llX", offset];

    NSMutableString *hex = [NSMutableString stringWithCapacity:48];
    NSMutableString *ascii = [NSMutableString stringWithCapacity:16];
    for (NSUInteger i = 0; i < kBytesPorFila; i++) {
        if (i < count) {
            uint8_t b = bytes[i];
            [hex appendFormat:@"%02X ", b];
            [ascii appendFormat:@"%c", (b >= 32 && b < 127) ? (char)b : '.'];
        } else {
            [hex appendString:@"   "];
            [ascii appendString:@" "];
        }
    }
    _hex.text = hex;
    _ascii.text = ascii;
}

@end
