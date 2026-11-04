#import "IRFileBrowserViewController.h"
#import "IRTheme.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRImportManager.h"
#import "IRDialog.h"

@interface IRFileBrowserViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *pickButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *pathLabel;
@property (nonatomic, strong) UIView *quickBar;
@property (nonatomic, strong) UIView *searchBox;
@property (nonatomic, strong) UIImageView *searchIcon;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<NSString *> *historial;
@property (nonatomic, copy) NSString *currentPath;
@property (nonatomic, strong) NSArray<NSDictionary *> *entries;
@property (nonatomic, strong) NSArray<NSDictionary *> *visibleEntries;
@end

@implementation IRFileBrowserViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _historial = [NSMutableArray array];
        _entries = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].background;

    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [IRTheme shared].elevatedBackground;
    [self.view addSubview:self.topBar];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setImage:[IRIcons icon:IRGlyphClose size:20 color:[IRTheme shared].textPrimary]
                      forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setImage:[IRIcons icon:IRGlyphChevronLeft size:20 color:[IRTheme shared].textPrimary]
                     forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(backTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.backButton];

    self.pickButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pickButton.backgroundColor = [IRTheme shared].accent;
    self.pickButton.layer.cornerRadius = 9;
    self.pickButton.titleLabel.font = [IRTheme shared].fontSubhead;
    [self.pickButton setTitle:@"Usar esta carpeta" forState:UIControlStateNormal];
    [self.pickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.pickButton addTarget:self action:@selector(pickTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    self.pickButton.hidden = !self.picksFolder;
    [self.topBar addSubview:self.pickButton];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [IRTheme shared].fontHeadline;
    self.titleLabel.textColor = [IRTheme shared].textPrimary;
    self.titleLabel.text = @"Archivos";
    [self.topBar addSubview:self.titleLabel];

    self.pathLabel = [[UILabel alloc] init];
    self.pathLabel.font = [IRTheme shared].fontCaption;
    self.pathLabel.textColor = [IRTheme shared].textSecondary;
    self.pathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.topBar addSubview:self.pathLabel];

    self.quickBar = [[UIView alloc] init];
    self.quickBar.backgroundColor = [IRTheme shared].background;
    [self.view addSubview:self.quickBar];

    NSArray *accesos = @[
        @[@"Documentos", [IRUtils documentsPath]],
        @[@"Importados", [IRUtils importedPath]],
        @[@"Medios", @"/var/mobile/Media"],
        @[@"iPad", @"/"]
    ];
    CGFloat anchoBoton = 0;
    for (NSInteger i = 0; i < accesos.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.backgroundColor = [IRTheme shared].controlFill;
        b.layer.cornerRadius = 9;
        b.titleLabel.font = [IRTheme shared].fontSubhead;
        [b setTitle:accesos[(NSUInteger)i][0] forState:UIControlStateNormal];
        [b setTitleColor:[IRTheme shared].textPrimary forState:UIControlStateNormal];
        [b setImage:[IRIcons icon:IRGlyphFolder size:16 color:[IRTheme shared].textSecondary]
           forState:UIControlStateNormal];
        b.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
        b.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
        [b addTarget:self action:@selector(quickTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.quickBar addSubview:b];
    }
    anchoBoton = 0;

    self.searchBox = [[UIView alloc] init];
    self.searchBox.backgroundColor = [IRTheme shared].fieldBackground;
    self.searchBox.layer.cornerRadius = 9;
    self.searchBox.layer.borderWidth = 1;
    self.searchBox.layer.borderColor = [IRTheme shared].separator.CGColor;
    [self.view addSubview:self.searchBox];

    self.searchIcon = [[UIImageView alloc] init];
    self.searchIcon.image = [IRIcons icon:IRGlyphSearch size:16 color:[IRTheme shared].textTertiary];
    self.searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.searchBox addSubview:self.searchIcon];

    self.searchField = [[UITextField alloc] init];
    self.searchField.placeholder = @"Filtrar esta carpeta";
    self.searchField.font = [IRTheme shared].fontBody;
    self.searchField.textColor = [IRTheme shared].textPrimary;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(searchChanged:)
               forControlEvents:UIControlEventEditingChanged];
    [self.searchBox addSubview:self.searchField];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [IRTheme shared].separator;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 58;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.font = [IRTheme shared].fontSubhead;
    self.emptyLabel.textColor = [IRTheme shared].textSecondary;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    NSString *inicio = self.startPath;
    if (!inicio.length || ![[NSFileManager defaultManager] fileExistsAtPath:inicio]) {
        inicio = [IRUtils documentsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:inicio]) inicio = @"/var/mobile";
    }
    [self loadPath:inicio pushHistory:NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat top = [IRUtils statusBarHeight];
    self.topBar.frame = CGRectMake(0, 0, w, top + 54);
    self.closeButton.frame = CGRectMake(10, top + 9, 36, 36);
    self.backButton.frame = CGRectMake(50, top + 9, 36, 36);
    self.titleLabel.frame = CGRectMake(94, top + 6, w - 110, 22);
    self.pathLabel.frame = CGRectMake(94, top + 28, w - 110, 16);
    if (self.picksFolder) {
        CGFloat anchoBoton = 152;
        self.pickButton.frame = CGRectMake(w - anchoBoton - 12, top + 9, anchoBoton, 36);
        self.titleLabel.frame = CGRectMake(94, top + 6, w - 110 - anchoBoton, 22);
        self.pathLabel.frame = CGRectMake(94, top + 28, w - 110 - anchoBoton, 16);
    }

    self.quickBar.frame = CGRectMake(0, CGRectGetMaxY(self.topBar.frame), w, 56);
    CGFloat qx = 16;
    CGFloat qw = (w - 32 - 3 * 8) / 4;
    for (UIView *v in self.quickBar.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            v.frame = CGRectMake(qx, 9, qw, 38);
            qx += qw + 8;
        }
    }

    self.searchBox.frame = CGRectMake(16, CGRectGetMaxY(self.quickBar.frame) + 2, w - 32, 36);
    self.searchIcon.frame = CGRectMake(10, 9, 17, 17);
    self.searchField.frame = CGRectMake(33, 0, w - 32 - 42, 36);
    self.tableView.frame = CGRectMake(0, CGRectGetMaxY(self.searchBox.frame) + 6, w,
                                      self.view.bounds.size.height - CGRectGetMaxY(self.searchBox.frame) - 6);
    self.emptyLabel.frame = CGRectMake(30, self.tableView.frame.origin.y + 80, w - 60, 60);
}

- (void)loadPath:(NSString *)path pushHistory:(BOOL)push {
    if (!path.length) return;
    NSString *normal = [path stringByStandardizingPath];
    if (push && self.currentPath.length) [self.historial addObject:self.currentPath];
    self.currentPath = normal;
    self.titleLabel.text = [normal lastPathComponent].length ? [normal lastPathComponent] : @"iPad";
    self.pathLabel.text = normal;
    self.searchField.text = @"";

    NSError *error = nil;
    NSArray *contenido = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:normal error:&error];
    if (!contenido) {
        self.entries = @[];
        self.emptyLabel.text = error.localizedDescription ?: @"No se puede abrir esta carpeta.";
        self.emptyLabel.hidden = NO;
        [self.tableView reloadData];
        return;
    }
    NSMutableArray *lista = [NSMutableArray array];
    for (NSString *nombre in contenido) {
        if ([nombre hasPrefix:@"."]) continue;
        NSString *ruta = [normal stringByAppendingPathComponent:nombre];
        BOOL dir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:ruta isDirectory:&dir]) continue;
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:ruta error:NULL];
        [lista addObject:@{
            @"name": nombre,
            @"path": ruta,
            @"dir": @(dir),
            @"size": attrs[NSFileSize] ?: @0,
            @"date": attrs[NSFileModificationDate] ?: [NSDate date]
        }];
    }
    [lista sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL da = [a[@"dir"] boolValue];
        BOOL db = [b[@"dir"] boolValue];
        if (da != db) return da ? NSOrderedAscending : NSOrderedDescending;
        return [IRUtils naturalCompare:a[@"name"] with:b[@"name"]];
    }];
    self.entries = lista;
    [self filterEntries];
}

- (void)filterEntries {
    NSString *q = [self.searchField.text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
    NSArray *base = self.entries;
    if (q.length) {
        NSMutableArray *filtrados = [NSMutableArray array];
        for (NSDictionary *e in base) {
            NSString *nombre = [e[@"name"] lowercaseString];
            if ([nombre rangeOfString:q].location != NSNotFound) {
                [filtrados addObject:e];
            }
        }
        base = filtrados;
    }
    self.visibleEntries = base;
    self.emptyLabel.hidden = (base.count > 0);
    if (base.count == 0) {
        self.emptyLabel.text = q.length ? @"Ningún archivo coincide con la búsqueda."
                                       : @"Esta carpeta está vacía.";
    }
    [self.tableView reloadData];
}

- (void)searchChanged:(UITextField *)field {
    [self filterEntries];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)dismissKeyboard {
    [self.searchField resignFirstResponder];
}

#pragma mark - Acciones

- (void)pickTapped:(UIButton *)sender {
    NSString *ruta = self.currentPath;
    if (!ruta.length) return;
    void (^callback)(NSString *) = self.onPickFolder;
    [self dismissViewControllerAnimated:YES completion:^{
        if (callback) callback(ruta);
    }];
}

- (void)closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backTapped:(UIButton *)sender {
    if (self.historial.count == 0) return;
    NSString *anterior = self.historial.lastObject;
    [self.historial removeLastObject];
    [self loadPath:anterior pushHistory:NO];
}

- (void)quickTapped:(UIButton *)sender {
    NSArray *rutas = @[[IRUtils documentsPath], [IRUtils importedPath], @"/var/mobile/Media", @"/"];
    NSInteger i = sender.tag;
    if (i < 0 || i >= (NSInteger)rutas.count) return;
    [self.historial removeAllObjects];
    [self loadPath:rutas[(NSUInteger)i] pushHistory:NO];
}

- (void)importPath:(NSString *)path {
    IRHUD *hud = [IRHUD showIn:self.view title:@"Importando" cancel:nil];
    [[IRImportManager shared] importFileAtPath:path move:NO completion:^(IRDocument *doc, NSError *error) {
        [hud hide];
        if (!doc) {
            [IRDialog showErrorIn:self error:error];
            return;
        }
        void (^callback)(IRDocument *) = self.onImport;
        [self dismissViewControllerAnimated:YES completion:^{
            if (callback) callback(doc);
        }];
    }];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.visibleEntries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identificador = @"archivo";
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:identificador];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identificador];
        celda.backgroundColor = [UIColor clearColor];
        celda.textLabel.font = [IRTheme shared].fontBody;
        celda.detailTextLabel.font = [IRTheme shared].fontCaption;
        celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [IRTheme shared].selectionFill;
        celda.selectedBackgroundView = sel;
    }
    NSDictionary *e = self.visibleEntries[(NSUInteger)indexPath.row];
    BOOL dir = [e[@"dir"] boolValue];
    NSString *nombre = e[@"name"];
    celda.textLabel.text = nombre;
    celda.textLabel.textColor = [IRTheme shared].textPrimary;
    celda.detailTextLabel.textColor = [IRTheme shared].textSecondary;

    IRDocumentType tipo = dir ? IRDocumentTypeFolder : [IRUtils typeForPath:e[@"path"]];
    UIImage *icono = [IRIcons icon:[IRUtils glyphForType:tipo] size:22
                             color:(dir ? [IRTheme shared].accent : [IRTheme shared].textSecondary)];
    celda.imageView.image = icono;

    if (dir) {
        celda.detailTextLabel.text = @"Carpeta";
    } else {
        NSString *fecha = [IRUtils relativeDateString:e[@"date"]];
        celda.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@",
                                      [IRUtils typeName:tipo],
                                      [IRUtils fileSizeString:[e[@"size"] unsignedLongLongValue]],
                                      fecha ?: @""];
        celda.accessoryType = UITableViewCellAccessoryNone;
    }
    if (dir) celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *e = self.visibleEntries[(NSUInteger)indexPath.row];
    if ([e[@"dir"] boolValue]) {
        [self loadPath:e[@"path"] pushHistory:YES];
    } else if (self.picksFolder) {
        [IRToast showIn:self.view message:@"Entra en una carpeta y pulsa «Usar esta carpeta»"];
    } else {
        [self importPath:e[@"path"]];
    }
}

@end
