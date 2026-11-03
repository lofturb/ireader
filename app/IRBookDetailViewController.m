#import "IRBookDetailViewController.h"
#import "IRRootViewController.h"
#import "IRTheme.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"
#import "IRBookCell.h"

@interface IRBookDetailViewController ()
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *topTitle;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIView *progressCard;
@property (nonatomic, strong) UILabel *progressTitle;
@property (nonatomic, strong) UILabel *progressValue;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIButton *readButton;
@property (nonatomic, strong) NSMutableArray<UIView *> *actionButtons;
@property (nonatomic, strong) UILabel *bookmarksTitle;
@property (nonatomic, strong) UIButton *addBookmarkButton;
@property (nonatomic, strong) NSMutableArray<UIView *> *bookmarkRows;
@property (nonatomic, strong) UILabel *collectionsTitle;
@property (nonatomic, strong) UIView *collectionsBox;
@property (nonatomic, assign) CGFloat builtWidth;
@end

@implementation IRBookDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        _actionButtons = [NSMutableArray array];
        _bookmarkRows = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].background;

    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [IRTheme shared].elevatedBackground;
    [self.view addSubview:self.topBar];

    self.topTitle = [[UILabel alloc] init];
    self.topTitle.text = @"Detalles";
    self.topTitle.font = [IRTheme shared].fontHeadline;
    self.topTitle.textColor = [IRTheme shared].textPrimary;
    [self.topBar addSubview:self.topTitle];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setImage:[IRIcons icon:IRGlyphClose size:19 color:[IRTheme shared].textPrimary]
                      forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    [self rebuildContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    self.topBar.frame = CGRectMake(0, 0, w, 54);
    self.topTitle.frame = CGRectMake(20, 16, w - 80, 22);
    self.closeButton.frame = CGRectMake(w - 48, 11, 36, 36);
    self.scrollView.frame = CGRectMake(0, 54, w, self.view.bounds.size.height - 54);
    if (fabs(w - self.builtWidth) > 0.5) {
        [self rebuildContent];
    }
}

- (void)rebuildContent {
    for (UIView *v in self.scrollView.subviews) [v removeFromSuperview];
    [self.actionButtons removeAllObjects];
    [self.bookmarkRows removeAllObjects];
    self.builtWidth = self.view.bounds.size.width;
    if (self.builtWidth < 10) self.builtWidth = 540;

    IRDocument *doc = self.document;
    if (!doc) return;
    IRTheme *tema = [IRTheme shared];
    CGFloat w = self.builtWidth;
    CGFloat contenidoW = w - 40;
    CGFloat y = 20;

    self.coverView = [[UIImageView alloc] init];
    self.coverView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverView.clipsToBounds = YES;
    self.coverView.layer.cornerRadius = 8;
    self.coverView.layer.borderWidth = 1;
    self.coverView.layer.borderColor = tema.separator.CGColor;
    UIImage *portada = nil;
    if (doc.coverName.length) portada = [IRUtils downsampleImageAtPath:[doc coverPath] maxPixelSize:640];
    if (!portada) portada = [IRBookCell coverImageForDocument:doc size:CGSizeMake(280, 380)];
    self.coverView.image = portada;
    self.coverView.frame = CGRectMake((w - 128) / 2, y, 128, 176);
    [self.scrollView addSubview:self.coverView];
    y += 190;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = doc.title;
    self.titleLabel.font = [UIFont fontWithName:@"Georgia-Bold" size:22] ?: [UIFont boldSystemFontOfSize:22];
    self.titleLabel.textColor = tema.textPrimary;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 3;
    CGSize tamTitulo = [self.titleLabel sizeThatFits:CGSizeMake(contenidoW, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(20, y, contenidoW, tamTitulo.height);
    [self.scrollView addSubview:self.titleLabel];
    y += tamTitulo.height + 4;

    self.authorLabel = [[UILabel alloc] init];
    self.authorLabel.text = doc.displayAuthor;
    self.authorLabel.font = [IRTheme shared].fontBody;
    self.authorLabel.textColor = tema.textSecondary;
    self.authorLabel.textAlignment = NSTextAlignmentCenter;
    self.authorLabel.numberOfLines = 2;
    CGSize tamAutor = [self.authorLabel sizeThatFits:CGSizeMake(contenidoW, CGFLOAT_MAX)];
    self.authorLabel.frame = CGRectMake(20, y, contenidoW, tamAutor.height);
    [self.scrollView addSubview:self.authorLabel];
    y += tamAutor.height + 8;

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.text = [NSString stringWithFormat:@"%@ · %@ · Añadido %@",
                           [IRUtils typeName:doc.type],
                           [IRUtils fileSizeString:doc.fileSize],
                           [IRUtils dateString:doc.addedAt]];
    self.metaLabel.font = [IRTheme shared].fontCaption;
    self.metaLabel.textColor = tema.textTertiary;
    self.metaLabel.textAlignment = NSTextAlignmentCenter;
    self.metaLabel.numberOfLines = 2;
    self.metaLabel.frame = CGRectMake(20, y, contenidoW, 32);
    [self.scrollView addSubview:self.metaLabel];
    y += 44;

    // Tarjeta de progreso.
    self.progressCard = [[UIView alloc] init];
    self.progressCard.backgroundColor = tema.cardBackground;
    self.progressCard.layer.cornerRadius = 12;
    self.progressCard.layer.borderWidth = 1;
    self.progressCard.layer.borderColor = tema.separator.CGColor;
    self.progressCard.frame = CGRectMake(20, y, contenidoW, 92);
    [self.scrollView addSubview:self.progressCard];

    self.progressTitle = [[UILabel alloc] init];
    self.progressTitle.text = @"Progreso de lectura";
    self.progressTitle.font = [IRTheme shared].fontSubhead;
    self.progressTitle.textColor = tema.textSecondary;
    self.progressTitle.frame = CGRectMake(14, 12, contenidoW - 28, 18);
    [self.progressCard addSubview:self.progressTitle];

    self.progressValue = [[UILabel alloc] init];
    self.progressValue.text = [doc pageLabel];
    self.progressValue.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.progressValue.textColor = tema.textPrimary;
    self.progressValue.textAlignment = NSTextAlignmentRight;
    self.progressValue.frame = CGRectMake(14, 12, contenidoW - 28, 18);
    [self.progressCard addSubview:self.progressValue];

    self.progressTrack = [[UIView alloc] init];
    self.progressTrack.backgroundColor = tema.controlFill;
    self.progressTrack.layer.cornerRadius = 3;
    self.progressTrack.frame = CGRectMake(14, 42, contenidoW - 28, 6);
    [self.progressCard addSubview:self.progressTrack];

    self.progressFill = [[UIView alloc] init];
    self.progressFill.backgroundColor = tema.accent;
    self.progressFill.layer.cornerRadius = 3;
    self.progressFill.frame = CGRectMake(0, 0,
        (contenidoW - 28) * MAX(0, MIN(1, [doc.progress fraction])), 6);
    [self.progressTrack addSubview:self.progressFill];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.text = [NSString stringWithFormat:@"Tiempo de lectura: %@%@",
                           [IRUtils formatDuration:doc.readingSeconds],
                           doc.favorite ? @"   ·   \u2605 Favorito" : @""];
    self.timeLabel.font = [IRTheme shared].fontCaption;
    self.timeLabel.textColor = tema.textTertiary;
    self.timeLabel.frame = CGRectMake(14, 58, contenidoW - 28, 18);
    [self.progressCard addSubview:self.timeLabel];
    y += 108;

    // Boton principal.
    self.readButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.readButton.backgroundColor = tema.accent;
    self.readButton.layer.cornerRadius = 10;
    self.readButton.titleLabel.font = [IRTheme shared].fontHeadline;
    [self.readButton setTitle:@"Continuar leyendo" forState:UIControlStateNormal];
    [self.readButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.readButton setImage:[IRIcons icon:IRGlyphBook size:19 color:[UIColor whiteColor]]
                     forState:UIControlStateNormal];
    self.readButton.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 6);
    self.readButton.frame = CGRectMake(20, y, contenidoW, 46);
    [self.readButton addTarget:self action:@selector(readTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.readButton];
    y += 58;

    // Acciones secundarias.
    NSArray *titulos = @[doc.favorite ? @"Favorito" : @"Favorito",
                         @"Colección", @"Editar", @"Eliminar"];
    NSArray *iconos = @[@(IRGlyphStar), @(IRGlyphFolder), @(IRGlyphNote), @(IRGlyphTrash)];
    CGFloat anchoAccion = (contenidoW - 24) / 4;
    for (NSInteger i = 0; i < titulos.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.backgroundColor = tema.controlFill;
        b.layer.cornerRadius = 9;
        b.titleLabel.font = [UIFont systemFontOfSize:12];
        [b setTitle:titulos[(NSUInteger)i] forState:UIControlStateNormal];
        [b setTitleColor:(i == 3 ? tema.danger : tema.textPrimary) forState:UIControlStateNormal];
        [b setImage:[IRIcons icon:(IRGlyph)[iconos[(NSUInteger)i] integerValue] size:17
                          color:(i == 3 ? tema.danger : tema.textSecondary)]
           forState:UIControlStateNormal];
        b.imageEdgeInsets = UIEdgeInsetsMake(-16, 0, 0, 0);
        b.titleEdgeInsets = UIEdgeInsetsMake(22, -16, 0, 0);
        b.frame = CGRectMake(20 + i * (anchoAccion + 8), y, anchoAccion, 54);
        [b addTarget:self action:@selector(secondaryTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:b];
        [self.actionButtons addObject:b];
    }
    y += 72;

    // Marcadores.
    self.bookmarksTitle = [[UILabel alloc] init];
    self.bookmarksTitle.text = @"Marcadores y notas";
    self.bookmarksTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.bookmarksTitle.textColor = tema.textPrimary;
    self.bookmarksTitle.frame = CGRectMake(20, y, contenidoW - 110, 22);
    [self.scrollView addSubview:self.bookmarksTitle];

    self.addBookmarkButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.addBookmarkButton.backgroundColor = tema.accentSoft;
    self.addBookmarkButton.layer.cornerRadius = 8;
    self.addBookmarkButton.titleLabel.font = [IRTheme shared].fontCaption;
    [self.addBookmarkButton setTitle:@"Añadir nota" forState:UIControlStateNormal];
    [self.addBookmarkButton setTitleColor:tema.accent forState:UIControlStateNormal];
    self.addBookmarkButton.frame = CGRectMake(w - 20 - 104, y - 3, 104, 28);
    [self.addBookmarkButton addTarget:self action:@selector(addBookmarkTapped:)
                     forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.addBookmarkButton];
    y += 32;

    if (doc.bookmarks.count == 0) {
        UILabel *vacio = [[UILabel alloc] init];
        vacio.text = @"Todavía no hay marcadores. Mientras lees, toca el icono del marcador para guardar la página.";
        vacio.font = [IRTheme shared].fontSubhead;
        vacio.textColor = tema.textTertiary;
        vacio.numberOfLines = 0;
        vacio.frame = CGRectMake(20, y, contenidoW, 42);
        [self.scrollView addSubview:vacio];
        y += 52;
    } else {
        for (IRBookmark *b in doc.bookmarks) {
            UIView *fila = [[UIView alloc] init];
            fila.backgroundColor = tema.cardBackground;
            fila.layer.cornerRadius = 10;
            fila.layer.borderWidth = 1;
            fila.layer.borderColor = tema.separator.CGColor;
            fila.frame = CGRectMake(20, y, contenidoW, 58);
            fila.tag = [doc.bookmarks indexOfObject:b];

            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(bookmarkTapped:)];
            [fila addGestureRecognizer:tap];

            UILabel *etiqueta = [[UILabel alloc] init];
            etiqueta.text = [NSString stringWithFormat:@"Pág. %ld · %@", (long)b.page,
                             [IRUtils relativeDateString:b.createdAt]];
            etiqueta.font = [IRTheme shared].fontCaption;
            etiqueta.textColor = tema.textSecondary;
            etiqueta.frame = CGRectMake(12, 8, contenidoW - 60, 16);
            [fila addSubview:etiqueta];

            UILabel *nota = [[UILabel alloc] init];
            nota.text = b.note.length ? b.note : @"Sin nota";
            nota.font = [IRTheme shared].fontSubhead;
            nota.textColor = b.note.length ? tema.textPrimary : tema.textTertiary;
            nota.numberOfLines = 2;
            nota.frame = CGRectMake(12, 25, contenidoW - 60, 30);
            [fila addSubview:nota];

            UIButton *borrar = [UIButton buttonWithType:UIButtonTypeCustom];
            [borrar setImage:[IRIcons icon:IRGlyphTrash size:16 color:tema.textTertiary]
                    forState:UIControlStateNormal];
            borrar.tag = [doc.bookmarks indexOfObject:b];
            borrar.frame = CGRectMake(contenidoW - 44, 14, 32, 30);
            [borrar addTarget:self action:@selector(deleteBookmarkTapped:)
             forControlEvents:UIControlEventTouchUpInside];
            [fila addSubview:borrar];

            [self.scrollView addSubview:fila];
            [self.bookmarkRows addObject:fila];
            y += 66;
        }
    }
    y += 4;

    // Colecciones.
    self.collectionsTitle = [[UILabel alloc] init];
    self.collectionsTitle.text = @"Colecciones";
    self.collectionsTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.collectionsTitle.textColor = tema.textPrimary;
    self.collectionsTitle.frame = CGRectMake(20, y, contenidoW, 22);
    [self.scrollView addSubview:self.collectionsTitle];
    y += 28;

    self.collectionsBox = [[UIView alloc] init];
    self.collectionsBox.frame = CGRectMake(20, y, contenidoW, 30);
    [self.scrollView addSubview:self.collectionsBox];
    CGFloat cx = 0;
    if (doc.collections.count == 0) {
        UILabel *sin = [[UILabel alloc] init];
        sin.text = @"Sin colecciones";
        sin.font = [IRTheme shared].fontSubhead;
        sin.textColor = tema.textTertiary;
        sin.frame = CGRectMake(0, 4, contenidoW, 20);
        [self.collectionsBox addSubview:sin];
    } else {
        for (NSString *nombre in doc.collections) {
            UILabel *chip = [[UILabel alloc] init];
            chip.text = nombre;
            chip.font = [IRTheme shared].fontCaption;
            chip.textColor = tema.accent;
            chip.backgroundColor = tema.accentSoft;
            chip.textAlignment = NSTextAlignmentCenter;
            chip.layer.cornerRadius = 9;
            chip.clipsToBounds = YES;
            CGSize tam = [chip sizeThatFits:CGSizeMake(contenidoW, 20)];
            CGFloat ancho = MIN(contenidoW, tam.width + 22);
            if (cx + ancho > contenidoW) break;
            chip.frame = CGRectMake(cx, 0, ancho, 24);
            [self.collectionsBox addSubview:chip];
            cx += ancho + 8;
        }
    }
    y += 46;

    self.scrollView.contentSize = CGSizeMake(w, y + 20);
}

#pragma mark - Acciones

- (void)closeTapped:(UIButton *)sender {
    if (self.onClose) self.onClose();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)readTapped:(UIButton *)sender {
    IRDocument *doc = self.document;
    NSInteger pagina = MAX(1, doc.progress.page);
    if (doc.progress.pageCount > 0 && pagina > doc.progress.pageCount) pagina = doc.progress.pageCount;
    [self dismissViewControllerAnimated:YES completion:^{
        [self.host openDocument:doc atPage:pagina];
    }];
}

- (void)secondaryTapped:(UIButton *)sender {
    IRDocument *doc = self.document;
    switch (sender.tag) {
        case 0: {
            doc.favorite = !doc.favorite;
            [[IRLibrary shared] save];
            [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
            [IRToast showIn:self.view message:doc.favorite ? @"Añadido a favoritos" : @"Quitado de favoritos"];
            [self rebuildContent];
            break;
        }
        case 1:
            [self showCollections];
            break;
        case 2:
            [self editMetadata];
            break;
        case 3:
            [self deleteDocument];
            break;
    }
}

- (void)showCollections {
    IRDocument *doc = self.document;
    NSMutableArray *acciones = [NSMutableArray array];
    for (NSString *nombre in [[IRLibrary shared] collections]) {
        BOOL dentro = [doc.collections containsObject:nombre];
        [acciones addObject:[IRDialogAction actionWithTitle:
                        [NSString stringWithFormat:@"%@ %@", dentro ? @"\u2713" : @"\u00b7", nombre]
                                                      style:(dentro ? IRDialogActionStyleSelected : IRDialogActionStyleDefault)
                                                    handler:^{
            [[IRLibrary shared] setDocument:doc inCollection:nombre added:!dentro];
            [self rebuildContent];
        }]];
    }
    [acciones addObject:[IRDialogAction actionWithTitle:@"Nueva colección" style:IRDialogActionStyleDefault handler:^{
        [IRDialog showPromptIn:self title:@"Nueva colección" message:@"Ponle un nombre."
                   placeholder:@"Nombre" text:@"" handler:^(NSString *texto) {
            if (!texto.length) return;
            [[IRLibrary shared] addCollection:texto];
            [[IRLibrary shared] setDocument:doc inCollection:texto added:YES];
            [self rebuildContent];
        }];
    }]];
    [IRDialog showSheetIn:self title:@"Colecciones" actions:acciones];
}

- (void)editMetadata {
    IRDocument *doc = self.document;
    [IRDialog showPromptIn:self title:@"Editar título" message:@"El título que se muestra en la biblioteca."
               placeholder:@"Título" text:doc.title handler:^(NSString *texto) {
        if (texto.length) doc.title = texto;
        [IRDialog showPromptIn:self title:@"Editar autor" message:@"Déjalo vacío si no lo conoces."
                   placeholder:@"Autor" text:doc.author ?: @"" handler:^(NSString *autor) {
            doc.author = autor ?: @"";
            [[IRLibrary shared] save];
            [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
            [self rebuildContent];
        }];
    }];
}

- (void)deleteDocument {
    IRDocument *doc = self.document;
    NSArray *acciones = @[
        [IRDialogAction actionWithTitle:@"Quitar de la biblioteca"
                                  style:IRDialogActionStyleDestructive
                                handler:^{
            [[IRLibrary shared] removeDocument:doc];
            [self dismissViewControllerAnimated:YES completion:^{
                if (self.onClose) self.onClose();
            }];
        }],
        [IRDialogAction actionWithTitle:@"Eliminar también el archivo"
                                  style:IRDialogActionStyleDestructive
                                handler:^{
            [[NSFileManager defaultManager] removeItemAtPath:doc.path error:NULL];
            [[IRLibrary shared] removeDocument:doc];
            [self dismissViewControllerAnimated:YES completion:^{
                if (self.onClose) self.onClose();
            }];
        }]
    ];
    [IRDialog showSheetIn:self title:@"Eliminar documento"
                  actions:acciones];
}

- (void)addBookmarkTapped:(UIButton *)sender {
    IRDocument *doc = self.document;
    NSInteger pagina = MAX(1, doc.progress.page);
    [IRDialog showPromptIn:self title:@"Nueva nota"
                   message:[NSString stringWithFormat:@"Página %ld. Escribe una nota o déjala vacía.", (long)pagina]
               placeholder:@"Nota" text:@"" handler:^(NSString *texto) {
        IRBookmark *b = [IRBookmark bookmarkWithPage:pagina index:doc.progress.index
                                              anchor:doc.progress.anchor
                                               label:[doc pageLabel]
                                                note:texto];
        [doc.bookmarks addObject:b];
        [[IRLibrary shared] save];
        [IRToast showIn:self.view message:@"Marcador guardado"];
        [self rebuildContent];
    }];
}

- (void)bookmarkTapped:(UITapGestureRecognizer *)tap {
    NSInteger i = tap.view.tag;
    IRDocument *doc = self.document;
    if (i < 0 || i >= (NSInteger)doc.bookmarks.count) return;
    IRBookmark *b = doc.bookmarks[(NSUInteger)i];
    [self dismissViewControllerAnimated:YES completion:^{
        [self.host openDocument:doc atPage:b.page];
    }];
}

- (void)deleteBookmarkTapped:(UIButton *)sender {
    IRDocument *doc = self.document;
    NSInteger i = sender.tag;
    if (i < 0 || i >= (NSInteger)doc.bookmarks.count) return;
    [doc.bookmarks removeObjectAtIndex:(NSUInteger)i];
    [[IRLibrary shared] save];
    [self rebuildContent];
}

@end
