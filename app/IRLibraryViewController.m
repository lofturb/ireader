#import "IRLibraryViewController.h"
#import "IRRootViewController.h"
#import "IRBookCell.h"
#import "IRBookDetailViewController.h"
#import "IRLibrary.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRDialog.h"

@interface IRLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout, UITextFieldDelegate>

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *sortButton;
@property (nonatomic, strong) UIButton *viewButton;
@property (nonatomic, strong) UIView *searchBox;
@property (nonatomic, strong) UIImageView *searchIcon;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIImageView *emptyIcon;
@property (nonatomic, strong) UILabel *emptyTitle;
@property (nonatomic, strong) UILabel *emptySubtitle;
@property (nonatomic, strong) UIButton *emptyButton;
@property (nonatomic, strong) NSArray<IRDocument *> *documents;
@property (nonatomic, assign) CGFloat lastWidth;
@end

@implementation IRLibraryViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _filter = IRLibraryFilterAll;
        _collectionName = @"";
        _screenTitle = @"Biblioteca";
        _documents = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].background;

    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [IRTheme shared].background;
    [self.view addSubview:self.headerView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [IRTheme shared].fontTitle;
    self.titleLabel.textColor = [IRTheme shared].textPrimary;
    [self.headerView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [IRTheme shared].fontCaption;
    self.subtitleLabel.textColor = [IRTheme shared].textSecondary;
    [self.headerView addSubview:self.subtitleLabel];

    self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.addButton.backgroundColor = [IRTheme shared].accent;
    self.addButton.layer.cornerRadius = 19;
    [self.addButton setImage:[IRIcons icon:IRGlyphPlus size:20 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    [self.addButton addTarget:self action:@selector(addTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.addButton];

    self.sortButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sortButton.layer.cornerRadius = 18;
    self.sortButton.backgroundColor = [IRTheme shared].controlFill;
    [self.sortButton setImage:[IRIcons icon:IRGlyphSort size:19 color:[IRTheme shared].textPrimary]
                     forState:UIControlStateNormal];
    [self.sortButton addTarget:self action:@selector(sortTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.sortButton];

    self.viewButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.viewButton.layer.cornerRadius = 18;
    self.viewButton.backgroundColor = [IRTheme shared].controlFill;
    [self.viewButton addTarget:self action:@selector(viewTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.viewButton];

    self.searchBox = [[UIView alloc] init];
    self.searchBox.backgroundColor = [IRTheme shared].fieldBackground;
    self.searchBox.layer.cornerRadius = 10;
    self.searchBox.layer.borderWidth = 1;
    self.searchBox.layer.borderColor = [IRTheme shared].separator.CGColor;
    [self.headerView addSubview:self.searchBox];

    self.searchIcon = [[UIImageView alloc] init];
    self.searchIcon.image = [IRIcons icon:IRGlyphSearch size:17 color:[IRTheme shared].textTertiary];
    self.searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.searchBox addSubview:self.searchIcon];

    self.searchField = [[UITextField alloc] init];
    self.searchField.placeholder = @"Buscar por título, autor o colección";
    self.searchField.font = [IRTheme shared].fontBody;
    self.searchField.textColor = [IRTheme shared].textPrimary;
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(searchChanged:)
               forControlEvents:UIControlEventEditingChanged];
    [self.searchBox addSubview:self.searchField];

    self.flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.flowLayout.minimumLineSpacing = 16;
    self.flowLayout.minimumInteritemSpacing = 16;
    self.flowLayout.sectionInset = UIEdgeInsetsMake(4, 20, 28, 20);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                             collectionViewLayout:self.flowLayout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    [self.collectionView registerClass:[IRBookCell class] forCellWithReuseIdentifier:@"libro"];
    [self.view addSubview:self.collectionView];

    UILongPressGestureRecognizer *pulsacion =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.collectionView addGestureRecognizer:pulsacion];

    [self buildEmptyView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryChanged:)
                                                 name:IRLibraryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
                                                 name:IRThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self reloadLibrary];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildEmptyView {
    self.emptyView = [[UIView alloc] init];
    self.emptyView.hidden = YES;
    [self.view addSubview:self.emptyView];

    self.emptyIcon = [[UIImageView alloc] init];
    self.emptyIcon.image = [IRIcons icon:IRGlyphLibrary size:56 color:[IRTheme shared].textTertiary];
    self.emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:self.emptyIcon];

    self.emptyTitle = [[UILabel alloc] init];
    self.emptyTitle.font = [IRTheme shared].fontHeadline;
    self.emptyTitle.textColor = [IRTheme shared].textPrimary;
    self.emptyTitle.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:self.emptyTitle];

    self.emptySubtitle = [[UILabel alloc] init];
    self.emptySubtitle.font = [IRTheme shared].fontSubhead;
    self.emptySubtitle.textColor = [IRTheme shared].textSecondary;
    self.emptySubtitle.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitle.numberOfLines = 0;
    [self.emptyView addSubview:self.emptySubtitle];

    self.emptyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.emptyButton.backgroundColor = [IRTheme shared].accent;
    self.emptyButton.layer.cornerRadius = 10;
    self.emptyButton.titleLabel.font = [IRTheme shared].fontHeadline;
    [self.emptyButton setTitle:@"Añadir documentos" forState:UIControlStateNormal];
    [self.emptyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.emptyButton addTarget:self action:@selector(addTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyView addSubview:self.emptyButton];
}

- (void)applyTheme {
    IRTheme *t = [IRTheme shared];
    self.view.backgroundColor = t.background;
    self.headerView.backgroundColor = t.background;
    self.titleLabel.textColor = t.textPrimary;
    self.subtitleLabel.textColor = t.textSecondary;
    self.addButton.backgroundColor = t.accent;
    self.sortButton.backgroundColor = t.controlFill;
    self.viewButton.backgroundColor = t.controlFill;
    [self.sortButton setImage:[IRIcons icon:IRGlyphSort size:19 color:t.textPrimary] forState:UIControlStateNormal];
    [self updateViewButton];
    self.searchBox.backgroundColor = t.fieldBackground;
    self.searchBox.layer.borderColor = t.separator.CGColor;
    self.searchField.textColor = t.textPrimary;
    self.searchIcon.image = [IRIcons icon:IRGlyphSearch size:17 color:t.textTertiary];
    self.emptyIcon.image = [IRIcons icon:IRGlyphLibrary size:56 color:t.textTertiary];
    self.emptyTitle.textColor = t.textPrimary;
    self.emptySubtitle.textColor = t.textSecondary;
    self.emptyButton.backgroundColor = t.accent;
    [self.collectionView reloadData];
}

- (void)updateViewButton {
    BOOL grid = ([IRSettings shared].libraryView == IRLibraryViewModeGrid);
    UIImage *icono = [IRIcons icon:(grid ? IRGlyphList : IRGlyphGrid) size:19
                             color:[IRTheme shared].textPrimary];
    [self.viewButton setImage:icono forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadLibrary];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat top = 20;
    self.headerView.frame = CGRectMake(0, 0, w, 118);
    self.titleLabel.frame = CGRectMake(20, top, w - 170, 34);
    self.subtitleLabel.frame = CGRectMake(20, top + 34, w - 170, 16);

    CGFloat bx = w - 20 - 38;
    self.addButton.frame = CGRectMake(bx, top + 2, 38, 38);
    bx -= 46;
    self.sortButton.frame = CGRectMake(bx, top + 2, 36, 36);
    bx -= 44;
    self.viewButton.frame = CGRectMake(bx, top + 2, 36, 36);

    self.searchBox.frame = CGRectMake(20, 78, w - 40, 36);
    self.searchIcon.frame = CGRectMake(10, 9, 18, 18);
    self.searchField.frame = CGRectMake(34, 0, w - 40 - 44, 36);

    self.collectionView.frame = CGRectMake(0, 118, w, self.view.bounds.size.height - 118);
    self.emptyView.frame = self.collectionView.frame;

    CGFloat ew = MIN(360, w - 60);
    self.emptyIcon.frame = CGRectMake((w - 56) / 2, self.collectionView.frame.origin.y + 90, 56, 56);
    self.emptyTitle.frame = CGRectMake((w - ew) / 2, self.collectionView.frame.origin.y + 160, ew, 24);
    self.emptySubtitle.frame = CGRectMake((w - ew) / 2, self.collectionView.frame.origin.y + 188, ew, 56);
    self.emptyButton.frame = CGRectMake((w - 190) / 2, self.collectionView.frame.origin.y + 258, 190, 44);

    if (fabs(w - self.lastWidth) > 0.5) {
        self.lastWidth = w;
        [self.flowLayout invalidateLayout];
    }
}

- (void)setFilter:(IRLibraryFilter)filter collection:(NSString *)collection title:(NSString *)title {
    self.filter = filter;
    self.collectionName = collection ?: @"";
    self.screenTitle = title.length ? title : @"Biblioteca";
    self.titleLabel.text = self.screenTitle;
    [self reloadLibrary];
}

#pragma mark - Datos

- (void)reloadLibrary {
    IRLibrary *biblioteca = [IRLibrary shared];
    NSArray *base = nil;
    switch (self.filter) {
        case IRLibraryFilterFavorites:
            base = [biblioteca.documents filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(IRDocument *d, NSDictionary *bindings) {
                return d.favorite;
            }]];
            break;
        case IRLibraryFilterReading:
            base = [biblioteca.documents filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(IRDocument *d, NSDictionary *bindings) {
                return !d.progress.finished && [d.progress fraction] > 0.001;
            }]];
            break;
        case IRLibraryFilterFinished:
            base = [biblioteca.documents filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(IRDocument *d, NSDictionary *bindings) {
                return d.progress.finished;
            }]];
            break;
        case IRLibraryFilterCollection:
            base = [biblioteca documentsInCollection:self.collectionName];
            break;
        default:
            base = biblioteca.documents;
            break;
    }

    if ([IRSettings shared].showOnlyReading && self.filter == IRLibraryFilterAll) {
        base = [base filteredArrayUsingPredicate:
                [NSPredicate predicateWithBlock:^BOOL(IRDocument *d, NSDictionary *bindings) {
            return !d.progress.finished && [d.progress fraction] > 0.001;
        }]];
    }

    NSString *consulta = [self.searchField.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (consulta.length) {
        NSMutableArray *filtrados = [NSMutableArray array];
        NSString *q = consulta.lowercaseString;
        for (IRDocument *d in base) {
            NSString *texto = [NSString stringWithFormat:@"%@ %@ %@ %@",
                               d.title ?: @"", d.author ?: @"", d.path ?: @"",
                               [d.collections componentsJoinedByString:@" "]];
            if ([texto.lowercaseString rangeOfString:q].location != NSNotFound) {
                [filtrados addObject:d];
            }
        }
        base = filtrados;
    }

    self.documents = [biblioteca sortedDocuments:base
                                             key:[IRSettings shared].librarySort
                                       ascending:[IRSettings shared].librarySortAscending];

    self.titleLabel.text = self.screenTitle;
    NSInteger leyendo = 0;
    for (IRDocument *d in biblioteca.documents) {
        if (!d.progress.finished && [d.progress fraction] > 0.001) leyendo++;
    }
    if (consulta.length) {
        self.subtitleLabel.text = [NSString stringWithFormat:@"%ld resultado%@",
                                   (long)self.documents.count, self.documents.count == 1 ? @"" : @"s"];
    } else if (self.filter == IRLibraryFilterAll) {
        self.subtitleLabel.text = [NSString stringWithFormat:@"%ld documento%@ · %ld en curso",
                                   (long)self.documents.count, self.documents.count == 1 ? @"" : @"s",
                                   (long)leyendo];
    } else {
        self.subtitleLabel.text = [NSString stringWithFormat:@"%ld documento%@",
                                   (long)self.documents.count, self.documents.count == 1 ? @"" : @"s"];
    }

    BOOL vacio = (self.documents.count == 0);
    self.emptyView.hidden = !vacio;
    self.collectionView.hidden = vacio;
    if (vacio) {
        if (consulta.length) {
            self.emptyTitle.text = @"Sin resultados";
            self.emptySubtitle.text = @"Prueba con otro título, autor o colección.";
            self.emptyButton.hidden = YES;
        } else if (self.filter == IRLibraryFilterFavorites) {
            self.emptyTitle.text = @"Sin favoritos";
            self.emptySubtitle.text = @"Marca un libro con la estrella para tenerlo siempre a mano.";
            self.emptyButton.hidden = YES;
        } else if (self.filter == IRLibraryFilterReading) {
            self.emptyTitle.text = @"Nada en curso";
            self.emptySubtitle.text = @"Los libros que empieces aparecerán aquí.";
            self.emptyButton.hidden = YES;
        } else if (self.filter == IRLibraryFilterFinished) {
            self.emptyTitle.text = @"Aún no has terminado ninguno";
            self.emptySubtitle.text = @"Cuando llegues a la última página lo verás aquí.";
            self.emptyButton.hidden = YES;
        } else if (self.filter == IRLibraryFilterCollection) {
            self.emptyTitle.text = @"Colección vacía";
            self.emptySubtitle.text = @"Añade libros a esta colección desde sus detalles.";
            self.emptyButton.hidden = YES;
        } else {
            self.emptyTitle.text = @"Tu biblioteca está vacía";
            self.emptySubtitle.text = @"Añade PDF, EPUB, cómics, imágenes o cualquier documento desde el iPad o por Wi-Fi.";
            self.emptyButton.hidden = NO;
        }
    }
    [self.collectionView reloadData];
}

- (void)libraryChanged:(NSNotification *)note {
    [self reloadLibrary];
}

- (void)themeChanged:(NSNotification *)note {
    [self applyTheme];
}

#pragma mark - Acciones

- (void)addTapped:(UIButton *)sender {
    [self.host showFileBrowser];
}

- (void)sortTapped:(UIButton *)sender {
    NSArray *titulos = @[@"Más recientes", @"Título", @"Autor", @"Fecha de alta"];
    NSMutableArray *acciones = [NSMutableArray array];
    for (NSInteger i = 0; i < titulos.count; i++) {
        IRLibrarySortKey clave = (IRLibrarySortKey)i;
        NSString *titulo = titulos[(NSUInteger)i];
        if ([IRSettings shared].librarySort == clave) titulo = [titulo stringByAppendingString:@"  \u2713"];
        IRDialogAction *a = [IRDialogAction actionWithTitle:titulo
                                                      style:([IRSettings shared].librarySort == clave
                                                             ? IRDialogActionStyleSelected
                                                             : IRDialogActionStyleDefault)
                                                    handler:^{
            [IRSettings shared].librarySort = clave;
            [[IRSettings shared] save];
            [self reloadLibrary];
        }];
        [acciones addObject:a];
    }
    NSString *orden = [IRSettings shared].librarySortAscending ? @"Invertir orden" : @"Volver al orden normal";
    [acciones addObject:[IRDialogAction actionWithTitle:orden
                                                  style:IRDialogActionStyleDefault
                                                handler:^{
        IRSettings *ajustes = [IRSettings shared];
        ajustes.librarySortAscending = !ajustes.librarySortAscending;
        [[IRSettings shared] save];
        [self reloadLibrary];
    }]];
    [IRDialog showSheetIn:self title:@"Ordenar biblioteca" actions:acciones];
}

- (void)viewTapped:(UIButton *)sender {
    IRSettings *ajustes = [IRSettings shared];
    ajustes.libraryView = (ajustes.libraryView == IRLibraryViewModeGrid)
        ? IRLibraryViewModeList : IRLibraryViewModeGrid;
    [ajustes save];
    [self updateViewButton];
    [self.flowLayout invalidateLayout];
    [self.collectionView reloadData];
}

- (void)searchChanged:(UITextField *)field {
    [self reloadLibrary];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)longPress:(UILongPressGestureRecognizer *)gesto {
    if (gesto.state != UIGestureRecognizerStateBegan) return;
    CGPoint punto = [gesto locationInView:self.collectionView];
    NSIndexPath *indice = [self.collectionView indexPathForItemAtPoint:punto];
    if (!indice) return;
    IRDocument *doc = self.documents[(NSUInteger)indice.item];
    [self showActionsForDocument:doc];
}

- (void)showActionsForDocument:(IRDocument *)doc {
    NSMutableArray *acciones = [NSMutableArray array];
    [acciones addObject:[IRDialogAction actionWithTitle:@"Leer" style:IRDialogActionStyleSelected handler:^{
        [self openDocument:doc];
    }]];
    [acciones addObject:[IRDialogAction actionWithTitle:@"Ver detalles" style:IRDialogActionStyleDefault handler:^{
        [self.host showDetailsForDocument:doc];
    }]];
    [acciones addObject:[IRDialogAction actionWithTitle:(doc.favorite ? @"Quitar de favoritos" : @"Añadir a favoritos")
                                                  style:IRDialogActionStyleDefault
                                                handler:^{
        doc.favorite = !doc.favorite;
        [[IRLibrary shared] save];
        [self reloadLibrary];
        [IRToast showIn:self.view message:doc.favorite ? @"Añadido a favoritos" : @"Quitado de favoritos"];
    }]];
    [acciones addObject:[IRDialogAction actionWithTitle:@"Añadir a colección"
                                                  style:IRDialogActionStyleDefault
                                                handler:^{
        [self showCollectionsForDocument:doc];
    }]];
    [acciones addObject:[IRDialogAction actionWithTitle:@"Eliminar de la biblioteca"
                                                  style:IRDialogActionStyleDestructive
                                                handler:^{
        [IRDialog showConfirmIn:self title:@"Eliminar de la biblioteca"
                        message:@"El archivo seguirá guardado en el iPad. Solo se quitará de IReader."
                    destructive:YES confirmTitle:@"Eliminar" handler:^{
            [[IRLibrary shared] removeDocument:doc];
            [self reloadLibrary];
            [IRToast showIn:self.view message:@"Eliminado de la biblioteca"];
        }];
    }]];
    [IRDialog showSheetIn:self title:doc.title actions:acciones];
}

- (void)showCollectionsForDocument:(IRDocument *)doc {
    NSArray *colecciones = [[IRLibrary shared] collections];
    NSMutableArray *acciones = [NSMutableArray array];
    for (NSString *nombre in colecciones) {
        BOOL dentro = [doc.collections containsObject:nombre];
        NSString *titulo = [NSString stringWithFormat:@"%@ %@", dentro ? @"\u2713" : @"\u00b7", nombre];
        [acciones addObject:[IRDialogAction actionWithTitle:titulo
                                                      style:(dentro ? IRDialogActionStyleSelected : IRDialogActionStyleDefault)
                                                    handler:^{
            [[IRLibrary shared] setDocument:doc inCollection:nombre added:!dentro];
            [self reloadLibrary];
            [IRToast showIn:self.view message:dentro ? @"Quitado de la colección" : @"Añadido a la colección"];
        }]];
    }
    [acciones addObject:[IRDialogAction actionWithTitle:@"Nueva colección" style:IRDialogActionStyleDefault handler:^{
        [IRDialog showPromptIn:self title:@"Nueva colección" message:@"Ponle un nombre."
                   placeholder:@"Por ejemplo: Novela negra" text:@"" handler:^(NSString *texto) {
            if (!texto.length) return;
            [[IRLibrary shared] addCollection:texto];
            [[IRLibrary shared] setDocument:doc inCollection:texto added:YES];
            [IRToast showIn:self.view message:@"Colección creada"];
            [self reloadLibrary];
        }];
    }]];
    [IRDialog showSheetIn:self title:@"Colecciones" actions:acciones];
}

- (void)openDocument:(IRDocument *)doc {
    if (doc.isMissing) {
        [IRDialog showConfirmIn:self title:@"Archivo no encontrado"
                        message:@"El archivo ya no está en la ruta original. ¿Quitarlo de la biblioteca?"
                    destructive:YES confirmTitle:@"Quitar" handler:^{
            [[IRLibrary shared] removeDocument:doc];
            [self reloadLibrary];
        }];
        return;
    }
    [self.host openDocument:doc];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)self.documents.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    IRBookCell *celda = [collectionView dequeueReusableCellWithReuseIdentifier:@"libro" forIndexPath:indexPath];
    celda.gridMode = ([IRSettings shared].libraryView == IRLibraryViewModeGrid);
    [celda configureWithDocument:self.documents[(NSUInteger)indexPath.item]];
    return celda;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat ancho = collectionView.bounds.size.width;
    if ([IRSettings shared].libraryView == IRLibraryViewModeList) {
        return CGSizeMake(MAX(200, ancho - 40), 88);
    }
    CGFloat columnas = (ancho >= 720) ? 4 : 3;
    CGFloat disponible = ancho - 40 - (columnas - 1) * 16;
    CGFloat w = floor(disponible / columnas);
    return CGSizeMake(w, floor(w * 1.30) + 62);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    [self openDocument:self.documents[(NSUInteger)indexPath.item]];
}

@end
