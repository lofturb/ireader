#import "IRRootViewController.h"
#import "IRLibraryViewController.h"
#import "IRFileBrowserViewController.h"
#import "IRBookDetailViewController.h"
#import "IRSettingsViewController.h"
#import "IRWiFiViewController.h"
#import "IRReaderContainerViewController.h"
#import "IRLibrary.h"
#import "IRImportManager.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRDialog.h"

#pragma mark - Celda lateral

@interface IRSidebarCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *countLabel;
- (void)configureWithTitle:(NSString *)title glyph:(IRGlyph)glyph selected:(BOOL)selected;
@end

@implementation IRSidebarCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_iconView];
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [self.contentView addSubview:_nameLabel];
        _countLabel = [[UILabel alloc] init];
        _countLabel.font = [IRTheme shared].fontCaption;
        _countLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_countLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.bounds.size.height;
    self.iconView.frame = CGRectMake(18, (h - 18) / 2, 18, 18);
    self.nameLabel.frame = CGRectMake(46, 0, self.contentView.bounds.size.width - 80, h);
    self.countLabel.frame = CGRectMake(self.contentView.bounds.size.width - 44, 0, 30, h);
}

- (void)configureWithTitle:(NSString *)title glyph:(IRGlyph)glyph selected:(BOOL)selected {
    IRTheme *t = [IRTheme shared];
    self.nameLabel.text = title;
    self.nameLabel.textColor = selected ? t.accent : t.textPrimary;
    self.nameLabel.font = [UIFont systemFontOfSize:15 weight:(selected ? UIFontWeightSemibold : UIFontWeightRegular)];
    self.iconView.image = [IRIcons icon:glyph size:18 color:(selected ? t.accent : t.textSecondary)];
    self.countLabel.text = @"";
    self.backgroundColor = selected ? t.accentSoft : [UIColor clearColor];
    self.contentView.layer.cornerRadius = 8;
    self.contentView.clipsToBounds = YES;
}

@end

#pragma mark - Raiz

@interface IRRootViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *sidebar;
@property (nonatomic, strong) UILabel *logoLabel;
@property (nonatomic, strong) UILabel *logoSubtitle;
@property (nonatomic, strong) UIView *logoLine;
@property (nonatomic, strong) UITableView *sidebarTable;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) IRLibraryViewController *libraryVC;
@property (nonatomic, strong) NSArray<NSDictionary *> *sections;
@property (nonatomic, assign) IRLibraryFilter selectedFilter;
@property (nonatomic, copy) NSString *selectedCollection;
@property (nonatomic, assign) BOOL openedLastBook;
- (void)showFolderPicker;
- (void)createFolderLibraryAtPath:(NSString *)path;
- (NSUInteger)syncFolderLibraryNamed:(NSString *)nombre path:(NSString *)path;
@end

@implementation IRRootViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedFilter = IRLibraryFilterAll;
        _selectedCollection = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].background;

    self.sidebar = [[UIView alloc] init];
    self.sidebar.backgroundColor = [IRTheme shared].sidebarBackground;
    [self.view addSubview:self.sidebar];

    self.logoLabel = [[UILabel alloc] init];
    self.logoLabel.text = @"IReader";
    self.logoLabel.font = [UIFont fontWithName:@"Georgia-Bold" size:28] ?: [UIFont boldSystemFontOfSize:28];
    self.logoLabel.textColor = [IRTheme shared].textPrimary;
    [self.sidebar addSubview:self.logoLabel];

    self.logoSubtitle = [[UILabel alloc] init];
    self.logoSubtitle.text = @"Biblioteca personal";
    self.logoSubtitle.font = [IRTheme shared].fontCaption;
    self.logoSubtitle.textColor = [IRTheme shared].textSecondary;
    [self.sidebar addSubview:self.logoSubtitle];

    self.logoLine = [[UIView alloc] init];
    self.logoLine.backgroundColor = [IRTheme shared].separator;
    [self.sidebar addSubview:self.logoLine];

    self.sidebarTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.sidebarTable.backgroundColor = [UIColor clearColor];
    self.sidebarTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.sidebarTable.dataSource = self;
    self.sidebarTable.delegate = self;
    self.sidebarTable.showsVerticalScrollIndicator = NO;
    self.sidebarTable.rowHeight = 42;
    self.sidebarTable.sectionHeaderHeight = 28;
    self.sidebarTable.contentInset = UIEdgeInsetsMake(4, 8, 8, 8);
    [self.sidebar addSubview:self.sidebarTable];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.text = @"v1.0.0";
    self.versionLabel.font = [IRTheme shared].fontCaption;
    self.versionLabel.textColor = [IRTheme shared].textTertiary;
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    [self.sidebar addSubview:self.versionLabel];

    self.contentContainer = [[UIView alloc] init];
    [self.view addSubview:self.contentContainer];

    self.libraryVC = [[IRLibraryViewController alloc] init];
    self.libraryVC.host = self;
    [self addChildViewController:self.libraryVC];
    self.libraryVC.view.frame = self.contentContainer.bounds;
    self.libraryVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentContainer addSubview:self.libraryVC.view];
    [self.libraryVC didMoveToParentViewController:self];

    [self reloadSidebar];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
                                                 name:IRThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryChanged:)
                                                 name:IRLibraryDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat sidebarW = [IRTheme shared].sidebarWidth;
    if (w < 760) sidebarW = 224;

    self.sidebar.frame = CGRectMake(0, 0, sidebarW, h);
    self.logoLabel.frame = CGRectMake(20, 30, sidebarW - 40, 34);
    self.logoSubtitle.frame = CGRectMake(20, 64, sidebarW - 40, 16);
    self.logoLine.frame = CGRectMake(20, 90, sidebarW - 40, 1);
    self.sidebarTable.frame = CGRectMake(0, 96, sidebarW, h - 96 - 36);
    self.versionLabel.frame = CGRectMake(0, h - 30, sidebarW, 18);
    self.contentContainer.frame = CGRectMake(sidebarW, 0, w - sidebarW, h);
    self.libraryVC.view.frame = self.contentContainer.bounds;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return [IRTheme shared].dark ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

#pragma mark - Datos del panel

- (void)reloadSidebar {
    NSMutableArray *colecciones = [NSMutableArray array];
    NSMutableSet *nombresDeBibliotecas = [NSMutableSet set];
    for (NSDictionary *lib in [IRLibrary shared].folderLibraries) {
        if ([lib[@"name"] isKindOfClass:[NSString class]]) [nombresDeBibliotecas addObject:lib[@"name"]];
    }
    for (NSString *nombre in [IRLibrary shared].collections) {
        if ([nombresDeBibliotecas containsObject:nombre]) continue;
        [colecciones addObject:@{@"title": nombre, @"glyph": @(IRGlyphFolder), @"kind": @"collection"}];
    }
    [colecciones addObject:@{@"title": @"Nueva colección", @"glyph": @(IRGlyphPlus), @"kind": @"newcollection"}];

    NSMutableArray *bibliotecas = [NSMutableArray array];
    for (NSDictionary *lib in [IRLibrary shared].folderLibraries) {
        [bibliotecas addObject:@{@"title": lib[@"name"] ?: @"Biblioteca",
                                 @"glyph": @(IRGlyphFolder),
                                 @"kind": @"folderlibrary",
                                 @"path": lib[@"path"] ?: @""}];
    }
    [bibliotecas addObject:@{@"title": @"Nueva biblioteca", @"glyph": @(IRGlyphPlus),
                             @"kind": @"newfolderlibrary"}];

    self.sections = @[
        @{@"title": @"BIBLIOTECA", @"items": @[
            @{@"title": @"Todos", @"glyph": @(IRGlyphLibrary), @"kind": @"all"},
            @{@"title": @"Favoritos", @"glyph": @(IRGlyphStar), @"kind": @"favorites"},
            @{@"title": @"Leyendo", @"glyph": @(IRGlyphBook), @"kind": @"reading"},
            @{@"title": @"Terminados", @"glyph": @(IRGlyphCheck), @"kind": @"finished"}
        ]},
        @{@"title": @"BIBLIOTECAS", @"items": bibliotecas},
        @{@"title": @"COLECCIONES", @"items": colecciones},
        @{@"title": @"HERRAMIENTAS", @"items": @[
            @{@"title": @"Archivos", @"glyph": @(IRGlyphFolder), @"kind": @"files"},
            @{@"title": @"Wi-Fi", @"glyph": @(IRGlyphWifi), @"kind": @"wifi"},
            @{@"title": @"Estadísticas", @"glyph": @(IRGlyphClock), @"kind": @"stats"},
            @{@"title": @"Ajustes", @"glyph": @(IRGlyphGear), @"kind": @"settings"}
        ]}
    ];
    [self.sidebarTable reloadData];
    [self restoreSidebarSelection];
}

- (void)restoreSidebarSelection {
    NSIndexPath *objetivo = nil;
    for (NSInteger s = 0; s < (NSInteger)self.sections.count && !objetivo; s++) {
        NSArray *items = self.sections[(NSUInteger)s][@"items"];
        for (NSInteger r = 0; r < (NSInteger)items.count; r++) {
            NSDictionary *item = items[(NSUInteger)r];
            NSString *kind = item[@"kind"];
            if (self.selectedFilter == IRLibraryFilterCollection &&
                ([kind isEqualToString:@"collection"] || [kind isEqualToString:@"folderlibrary"]) &&
                [item[@"title"] isEqualToString:self.selectedCollection]) {
                objetivo = [NSIndexPath indexPathForRow:r inSection:s];
                break;
            }
            if ([kind isEqualToString:@"all"] && self.selectedFilter == IRLibraryFilterAll) {
                objetivo = [NSIndexPath indexPathForRow:r inSection:s]; break;
            }
            if ([kind isEqualToString:@"favorites"] && self.selectedFilter == IRLibraryFilterFavorites) {
                objetivo = [NSIndexPath indexPathForRow:r inSection:s]; break;
            }
            if ([kind isEqualToString:@"reading"] && self.selectedFilter == IRLibraryFilterReading) {
                objetivo = [NSIndexPath indexPathForRow:r inSection:s]; break;
            }
            if ([kind isEqualToString:@"finished"] && self.selectedFilter == IRLibraryFilterFinished) {
                objetivo = [NSIndexPath indexPathForRow:r inSection:s]; break;
            }
        }
    }
    if (objetivo) [self.sidebarTable selectRowAtIndexPath:objetivo animated:NO
                                          scrollPosition:UITableViewScrollPositionNone];
}

- (void)applyTheme {
    IRTheme *t = [IRTheme shared];
    self.view.backgroundColor = t.background;
    self.sidebar.backgroundColor = t.sidebarBackground;
    self.logoLabel.textColor = t.textPrimary;
    self.logoSubtitle.textColor = t.textSecondary;
    self.logoLine.backgroundColor = t.separator;
    self.versionLabel.textColor = t.textTertiary;
    [self.sidebarTable reloadData];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)themeChanged:(NSNotification *)note {
    [self applyTheme];
}

- (void)libraryChanged:(NSNotification *)note {
    [self reloadSidebar];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.sections[(NSUInteger)section][@"items"] count];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *v = [[UIView alloc] init];
    UILabel *l = [[UILabel alloc] init];
    l.text = self.sections[(NSUInteger)section][@"title"];
    l.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    l.textColor = [IRTheme shared].textTertiary;
    l.frame = CGRectMake(18, 10, tableView.bounds.size.width - 36, 14);
    [v addSubview:l];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IRSidebarCell *celda = [tableView dequeueReusableCellWithIdentifier:@"lateral"];
    if (!celda) {
        celda = [[IRSidebarCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"lateral"];
    }
    NSDictionary *item = self.sections[(NSUInteger)indexPath.section][@"items"][(NSUInteger)indexPath.row];
    NSString *kind = item[@"kind"];
    BOOL seleccionado = NO;
    if ([kind isEqualToString:@"all"]) seleccionado = (self.selectedFilter == IRLibraryFilterAll);
    else if ([kind isEqualToString:@"favorites"]) seleccionado = (self.selectedFilter == IRLibraryFilterFavorites);
    else if ([kind isEqualToString:@"reading"]) seleccionado = (self.selectedFilter == IRLibraryFilterReading);
    else if ([kind isEqualToString:@"finished"]) seleccionado = (self.selectedFilter == IRLibraryFilterFinished);
    else if ([kind isEqualToString:@"collection"] || [kind isEqualToString:@"folderlibrary"]) {
        seleccionado = (self.selectedFilter == IRLibraryFilterCollection &&
                        [item[@"title"] isEqualToString:self.selectedCollection]);
    }
    [celda configureWithTitle:item[@"title"]
                        glyph:(IRGlyph)[item[@"glyph"] integerValue]
                     selected:seleccionado];
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.sections[(NSUInteger)indexPath.section][@"items"][(NSUInteger)indexPath.row];
    NSString *kind = item[@"kind"];
    NSString *titulo = item[@"title"];

    if ([kind isEqualToString:@"all"]) {
        self.selectedFilter = IRLibraryFilterAll;
        self.selectedCollection = @"";
        [self.libraryVC setFilter:IRLibraryFilterAll collection:nil title:@"Biblioteca"];
    } else if ([kind isEqualToString:@"favorites"]) {
        self.selectedFilter = IRLibraryFilterFavorites;
        self.selectedCollection = @"";
        [self.libraryVC setFilter:IRLibraryFilterFavorites collection:nil title:@"Favoritos"];
    } else if ([kind isEqualToString:@"reading"]) {
        self.selectedFilter = IRLibraryFilterReading;
        self.selectedCollection = @"";
        [self.libraryVC setFilter:IRLibraryFilterReading collection:nil title:@"Leyendo"];
    } else if ([kind isEqualToString:@"finished"]) {
        self.selectedFilter = IRLibraryFilterFinished;
        self.selectedCollection = @"";
        [self.libraryVC setFilter:IRLibraryFilterFinished collection:nil title:@"Terminados"];
    } else if ([kind isEqualToString:@"folderlibrary"]) {
        self.selectedFilter = IRLibraryFilterCollection;
        self.selectedCollection = titulo;
        [self syncFolderLibraryNamed:titulo path:item[@"path"]];
        [self.libraryVC setFilter:IRLibraryFilterCollection collection:titulo title:titulo];
    } else if ([kind isEqualToString:@"newfolderlibrary"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        [self showFolderPicker];
        return;
    } else if ([kind isEqualToString:@"collection"]) {
        self.selectedFilter = IRLibraryFilterCollection;
        self.selectedCollection = titulo;
        [self.libraryVC setFilter:IRLibraryFilterCollection collection:titulo title:titulo];
    } else if ([kind isEqualToString:@"newcollection"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        [IRDialog showPromptIn:self title:@"Nueva colección"
                       message:@"Agrupa tus libros por tema, autor o lo que prefieras."
                   placeholder:@"Nombre de la colección" text:@"" handler:^(NSString *texto) {
            if (!texto.length) return;
            [[IRLibrary shared] addCollection:texto];
            [self reloadSidebar];
            [IRToast showIn:self.view message:@"Colección creada"];
        }];
        return;
    } else if ([kind isEqualToString:@"files"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        [self showFileBrowser];
        return;
    } else if ([kind isEqualToString:@"wifi"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        IRWiFiViewController *wifi = [[IRWiFiViewController alloc] init];
        wifi.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:wifi animated:YES completion:nil];
        return;
    } else if ([kind isEqualToString:@"stats"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        [self showStatistics];
        return;
    } else if ([kind isEqualToString:@"settings"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self restoreSidebarSelection];
        IRSettingsViewController *ajustes = [[IRSettingsViewController alloc] init];
        ajustes.host = self;
        ajustes.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:ajustes animated:YES completion:nil];
        return;
    }
    [self.sidebarTable reloadData];
    [self restoreSidebarSelection];
}

#pragma mark - Bibliotecas de carpeta

- (void)showFolderPicker {
    IRFileBrowserViewController *navegador = [[IRFileBrowserViewController alloc] init];
    navegador.startPath = [IRUtils documentsPath];
    navegador.picksFolder = YES;
    navegador.onPickFolder = ^(NSString *ruta) {
        [self createFolderLibraryAtPath:ruta];
    };
    navegador.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navegador animated:YES completion:nil];
}

- (void)createFolderLibraryAtPath:(NSString *)path {
    if (!path.length) return;
    NSString *nombre = [path lastPathComponent];
    if (!nombre.length) nombre = @"Biblioteca";
    IRLibrary *biblioteca = [IRLibrary shared];
    [biblioteca addFolderLibraryNamed:nombre path:path];
    [biblioteca addCollection:nombre];

    NSUInteger nuevos = [self syncFolderLibraryNamed:nombre path:path];

    self.selectedFilter = IRLibraryFilterCollection;
    self.selectedCollection = nombre;
    [self.libraryVC setFilter:IRLibraryFilterCollection collection:nombre title:nombre];
    [self reloadSidebar];
    [self.libraryVC reloadLibrary];

    NSString *mensaje = (nuevos > 0)
        ? [NSString stringWithFormat:@"Biblioteca «%@» con %lu documento%@",
           nombre, (unsigned long)nuevos, nuevos == 1 ? @"" : @"s"]
        : [NSString stringWithFormat:@"Biblioteca «%@» actualizada", nombre];
    [IRToast showIn:self.view message:mensaje];
}

// Registra los archivos de la carpeta que aun no esten en la biblioteca y los
// agrupa en la coleccion con el mismo nombre. Devuelve cuantos son nuevos.
- (NSUInteger)syncFolderLibraryNamed:(NSString *)nombre path:(NSString *)path {
    if (!nombre.length || !path.length) return 0;
    IRLibrary *biblioteca = [IRLibrary shared];
    NSArray *archivos = [IRUtils supportedFilesInFolder:path recursive:YES];
    NSMutableArray *recienLlegados = [NSMutableArray array];
    for (NSString *ruta in archivos) {
        BOOL existia = ([biblioteca documentWithPath:ruta] != nil);
        IRDocument *doc = [biblioteca indexDocumentAtPath:ruta];
        if (!doc) continue;
        if (![doc.collections containsObject:nombre]) [doc.collections addObject:nombre];
        if (!existia) [recienLlegados addObject:doc];
    }
    [biblioteca save];
    [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification
                                                        object:biblioteca];
    for (IRDocument *doc in recienLlegados) {
        [[IRImportManager shared] refreshMetadataForDocument:doc];
    }
    return recienLlegados.count;
}

#pragma mark - Acciones

- (void)openDocument:(IRDocument *)document {
    [self openDocument:document atPage:0];
}

- (void)openDocument:(IRDocument *)document atPage:(NSInteger)page {
    if (!document) return;
    document.lastOpenedAt = [NSDate date];
    [[IRLibrary shared] save];
    [IRSettings shared].lastBookID = document.identifier;
    [[IRSettings shared] save];

    IRReaderContainerViewController *lector =
        [[IRReaderContainerViewController alloc] initWithDocument:document];
    lector.initialPage = page;
    lector.modalPresentationStyle = UIModalPresentationFullScreen;
    lector.onClose = ^{
        [self.libraryVC reloadLibrary];
        [self setNeedsStatusBarAppearanceUpdate];
    };
    [self presentViewController:lector animated:YES completion:nil];
}

- (void)showFileBrowser {
    IRFileBrowserViewController *navegador = [[IRFileBrowserViewController alloc] init];
    navegador.startPath = [IRUtils documentsPath];
    navegador.onImport = ^(IRDocument *doc) {
        [self.libraryVC reloadLibrary];
        if (doc) [self openDocument:doc];
    };
    navegador.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navegador animated:YES completion:nil];
}

- (void)showDetailsForDocument:(IRDocument *)document {
    if (!document) return;
    IRBookDetailViewController *detalle = [[IRBookDetailViewController alloc] init];
    detalle.document = document;
    detalle.host = self;
    detalle.onClose = ^{ [self.libraryVC reloadLibrary]; };
    [self presentViewController:detalle animated:YES completion:nil];
}

- (void)showStatistics {
    NSDictionary *stats = [[IRLibrary shared] statistics];
    NSString *mensaje = [NSString stringWithFormat:
        @"Tiempo total de lectura: %@\nHoy: %@\nRacha: %ld día%@\n\nLibros: %ld\nEn curso: %ld\nTerminados: %ld\nPáginas leídas: %ld",
        [IRUtils formatDuration:[stats[@"seconds"] doubleValue]],
        [IRUtils formatDuration:[stats[@"today"] doubleValue]],
        (long)[stats[@"streak"] integerValue], [stats[@"streak"] integerValue] == 1 ? @"" : @"s",
        (long)[stats[@"books"] integerValue],
        (long)[stats[@"reading"] integerValue],
        (long)[stats[@"finished"] integerValue],
        (long)[stats[@"pages"] integerValue]];
    [IRDialog showAlertIn:self title:@"Tus estadísticas" message:mensaje];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.openedLastBook) return;
    self.openedLastBook = YES;
    if (![IRSettings shared].openLastBook) return;
    NSString *ultimo = [IRSettings shared].lastBookID;
    IRDocument *doc = [[IRLibrary shared] documentWithID:ultimo];
    if (doc && !doc.isMissing) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self openDocument:doc];
        });
    }
}

@end
