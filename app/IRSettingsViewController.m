#import "IRSettingsViewController.h"
#import "IRRootViewController.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"

@interface IRSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation IRSettingsViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].background;

    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [IRTheme shared].elevatedBackground;
    [self.view addSubview:self.topBar];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"Ajustes";
    self.titleLabel.font = [IRTheme shared].fontHeadline;
    self.titleLabel.textColor = [IRTheme shared].textPrimary;
    [self.topBar addSubview:self.titleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setImage:[IRIcons icon:IRGlyphClose size:20 color:[IRTheme shared].textPrimary]
                      forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = [IRTheme shared].background;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorColor = [IRTheme shared].separator;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
                                                 name:IRThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat top = [IRUtils statusBarHeight];
    self.topBar.frame = CGRectMake(0, 0, w, top + 52);
    self.titleLabel.frame = CGRectMake(20, top + 15, w - 80, 22);
    self.closeButton.frame = CGRectMake(w - 48, top + 10, 36, 36);
    self.tableView.frame = CGRectMake(0, top + 52, w, self.view.bounds.size.height - top - 52);
}

- (void)themeChanged:(NSNotification *)note {
    self.view.backgroundColor = [IRTheme shared].background;
    self.topBar.backgroundColor = [IRTheme shared].elevatedBackground;
    self.titleLabel.textColor = [IRTheme shared].textPrimary;
    [self.closeButton setImage:[IRIcons icon:IRGlyphClose size:20 color:[IRTheme shared].textPrimary]
                      forState:UIControlStateNormal];
    self.tableView.backgroundColor = [IRTheme shared].background;
    self.tableView.separatorColor = [IRTheme shared].separator;
    [self.tableView reloadData];
}

- (void)closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 7; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Apariencia";
        case 1: return @"Lectura";
        case 2: return @"Biblioteca";
        case 3: return @"Pantalla";
        case 4: return @"Servidor Wi-Fi";
        case 5: return @"Datos";
        default: return @"Acerca de IReader";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 10;
        case 2: return 5;
        case 3: return 2;
        case 4: return 1;
        case 5: return 2;
        default: return 2;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 1) return 62;
    return 50;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"El modo original respeta las fuentes, márgenes y tamaño de página del documento. Desactívalo solo si prefieres una lectura reajustada.";
    }
    if (section == 4) {
        return @"Abre el panel Wi-Fi desde la barra lateral para ver la dirección y subir archivos desde el ordenador.";
    }
    return nil;
}

- (UITableViewCell *)cellForIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                    reuseIdentifier:nil];
    celda.backgroundColor = [IRTheme shared].cardBackground;
    celda.textLabel.font = [IRTheme shared].fontBody;
    celda.textLabel.textColor = [IRTheme shared].textPrimary;
    celda.detailTextLabel.font = [IRTheme shared].fontSubhead;
    celda.detailTextLabel.textColor = [IRTheme shared].textSecondary;
    celda.selectionStyle = UITableViewCellSelectionStyleNone;

    UIView *sel = [[UIView alloc] init];
    sel.backgroundColor = [IRTheme shared].selectionFill;
    celda.selectedBackgroundView = sel;

    IRSettings *ajustes = [IRSettings shared];
    NSInteger tag = indexPath.section * 100 + indexPath.row;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            celda.textLabel.text = @"Modo oscuro";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = ajustes.appDark;
            sw.onTintColor = [IRTheme shared].accent;
            sw.tag = tag;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            celda.accessoryView = sw;
        } else {
            celda.textLabel.text = @"Color de acento";
            celda.textLabel.frame = CGRectMake(20, 8, celda.contentView.bounds.size.width, 20);
            NSArray *colores = @[@0xB4552F, @0x2F6B63, @0x5A4B8C, @0x2F5C8C, @0x7A6A2F];
            CGFloat x = 20;
            for (NSInteger i = 0; i < colores.count; i++) {
                UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
                b.tag = i;
                b.frame = CGRectMake(x, 32, 28, 28);
                b.backgroundColor = [IRTheme colorWithHex:[colores[(NSUInteger)i] unsignedIntegerValue] alpha:1];
                b.layer.cornerRadius = 14;
                b.layer.borderWidth = (ajustes.accentIndex == i) ? 3 : 1;
                b.layer.borderColor = (ajustes.accentIndex == i)
                    ? [IRTheme shared].textPrimary.CGColor
                    : [IRTheme shared].separator.CGColor;
                [b addTarget:self action:@selector(accentTapped:) forControlEvents:UIControlEventTouchUpInside];
                [celda.contentView addSubview:b];
                x += 38;
            }
        }
        return celda;
    }

    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: {
                celda.textLabel.text = @"Tema de lectura";
                UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:
                                           @[@"Original", @"Papel", @"Sepia", @"Noche", @"Negro"]];
                seg.frame = CGRectMake(0, 0, 320, 30);
                seg.selectedSegmentIndex = ajustes.readingTheme;
                seg.tintColor = [IRTheme shared].accent;
                seg.tag = tag;
                [seg addTarget:self action:@selector(readingThemeChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = seg;
                break;
            }
            case 1: {
                celda.textLabel.text = @"Tamaño de texto";
                celda.detailTextLabel.text = [NSString stringWithFormat:@"%.0f pt", ajustes.readingFontSize];
                UIStepper *st = [[UIStepper alloc] init];
                st.minimumValue = 12;
                st.maximumValue = 34;
                st.stepValue = 1;
                st.value = ajustes.readingFontSize;
                st.tag = tag;
                [st addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = st;
                break;
            }
            case 2: {
                celda.textLabel.text = @"Tipografía";
                celda.detailTextLabel.text = ajustes.readingFontFamily;
                celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                celda.selectionStyle = UITableViewCellSelectionStyleDefault;
                break;
            }
            case 3: {
                celda.textLabel.text = @"Interlineado";
                UISlider *s = [[UISlider alloc] init];
                s.frame = CGRectMake(0, 0, 180, 30);
                s.minimumValue = 0;
                s.maximumValue = 18;
                s.value = ajustes.readingLineSpacing;
                s.tintColor = [IRTheme shared].accent;
                s.tag = tag;
                [s addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = s;
                break;
            }
            case 4: {
                celda.textLabel.text = @"Márgenes";
                UISlider *s = [[UISlider alloc] init];
                s.frame = CGRectMake(0, 0, 180, 30);
                s.minimumValue = 12;
                s.maximumValue = 72;
                s.value = ajustes.readingMargin;
                s.tintColor = [IRTheme shared].accent;
                s.tag = tag;
                [s addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = s;
                break;
            }
            case 5: {
                celda.textLabel.text = @"Justificar texto";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.readingJustify;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
            case 6: {
                celda.textLabel.text = @"Guiones automáticos";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.readingHyphenate;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
            case 7: {
                celda.textLabel.text = @"Diseño original del documento";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.originalLayout;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
            case 8: {
                celda.textLabel.text = @"Desplazamiento del PDF";
                celda.detailTextLabel.text = (ajustes.pdfScrollDirection == IRPDFScrollDirectionVertical)
                    ? @"Vertical" : @"Horizontal";
                celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                celda.selectionStyle = UITableViewCellSelectionStyleDefault;
                break;
            }
            default: {
                celda.textLabel.text = @"Bloquear desplazamiento lateral";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.lockScrollAxis;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
        }
        return celda;
    }

    if (indexPath.section == 2) {
        switch (indexPath.row) {
            case 0: {
                celda.textLabel.text = @"Vista";
                UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"Cuadrícula", @"Lista"]];
                seg.frame = CGRectMake(0, 0, 180, 30);
                seg.selectedSegmentIndex = ajustes.libraryView;
                seg.tintColor = [IRTheme shared].accent;
                seg.tag = tag;
                [seg addTarget:self action:@selector(libraryViewChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = seg;
                break;
            }
            case 1: {
                celda.textLabel.text = @"Ordenar por";
                NSArray *nombres = @[@"Más recientes", @"Título", @"Autor", @"Fecha de alta"];
                celda.detailTextLabel.text = nombres[MIN((NSUInteger)ajustes.librarySort, nombres.count - 1)];
                celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                celda.selectionStyle = UITableViewCellSelectionStyleDefault;
                break;
            }
            case 2: {
                celda.textLabel.text = @"Orden ascendente";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.librarySortAscending;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
            case 3: {
                celda.textLabel.text = @"Mostrar progreso";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.showProgressBars;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
            default: {
                celda.textLabel.text = @"Solo libros en curso";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = ajustes.showOnlyReading;
                sw.onTintColor = [IRTheme shared].accent;
                sw.tag = tag;
                [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                celda.accessoryView = sw;
                break;
            }
        }
        return celda;
    }

    if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            celda.textLabel.text = @"Mantener pantalla encendida";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = ajustes.keepAwake;
            sw.onTintColor = [IRTheme shared].accent;
            sw.tag = tag;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            celda.accessoryView = sw;
        } else {
            celda.textLabel.text = @"Brillo de lectura";
            UISlider *s = [[UISlider alloc] init];
            s.frame = CGRectMake(0, 0, 180, 30);
            s.minimumValue = 0.35;
            s.maximumValue = 1.0;
            s.value = ajustes.readingBrightness;
            s.tintColor = [IRTheme shared].accent;
            s.tag = tag;
            [s addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
            celda.accessoryView = s;
        }
        return celda;
    }

    if (indexPath.section == 4) {
        celda.textLabel.text = @"Puerto del servidor";
        celda.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)ajustes.wifiPort];
        celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
        return celda;
    }

    if (indexPath.section == 5) {
        if (indexPath.row == 0) {
            celda.textLabel.text = @"Restablecer ajustes de lectura";
            celda.textLabel.textColor = [IRTheme shared].accent;
            celda.selectionStyle = UITableViewCellSelectionStyleDefault;
        } else {
            celda.textLabel.text = @"Vaciar caché de documentos";
            celda.textLabel.textColor = [IRTheme shared].danger;
            celda.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        return celda;
    }

    if (indexPath.row == 0) {
        celda.textLabel.text = @"Versión";
        celda.detailTextLabel.text = @"1.0.0 (iOS 9+)";
    } else {
        celda.textLabel.text = @"Licencia y créditos";
        celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self cellForIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IRSettings *ajustes = [IRSettings shared];

    if (indexPath.section == 1 && indexPath.row == 2) {
        NSArray *fuentes = @[@"Georgia", @"Palatino", @"Times New Roman", @"Helvetica Neue", @"Menlo", @"System"];
        NSMutableArray *acciones = [NSMutableArray array];
        for (NSString *f in fuentes) {
            BOOL sel = [ajustes.readingFontFamily isEqualToString:f];
            [acciones addObject:[IRDialogAction actionWithTitle:(sel ? [@"\u2713 " stringByAppendingString:f] : f)
                                                          style:(sel ? IRDialogActionStyleSelected : IRDialogActionStyleDefault)
                                                        handler:^{
                ajustes.readingFontFamily = f;
                [ajustes save];
                [tableView reloadData];
                [IRToast showIn:self.view message:[NSString stringWithFormat:@"Tipografía: %@", f]];
            }]];
        }
        [IRDialog showSheetIn:self title:@"Tipografía" actions:acciones];
        return;
    }

    if (indexPath.section == 1 && indexPath.row == 8) {
        NSArray *titulos = @[@"Vertical (flujo continuo)", @"Horizontal (página a página)"];
        NSMutableArray *acciones = [NSMutableArray array];
        for (NSInteger i = 0; i < (NSInteger)titulos.count; i++) {
            BOOL sel = ((NSInteger)ajustes.pdfScrollDirection == i);
            NSString *titulo = sel ? [@"\u2713 " stringByAppendingString:titulos[(NSUInteger)i]]
                                   : titulos[(NSUInteger)i];
            [acciones addObject:[IRDialogAction actionWithTitle:titulo
                                                          style:(sel ? IRDialogActionStyleSelected
                                                                     : IRDialogActionStyleDefault)
                                                        handler:^{
                ajustes.pdfScrollDirection = (IRPDFScrollDirection)i;
                [ajustes save];
                [tableView reloadData];
                [IRToast showIn:self.view message:(i == 0 ? @"PDF vertical" : @"PDF horizontal")];
            }]];
        }
        [IRDialog showSheetIn:self title:@"Desplazamiento del PDF" actions:acciones];
        return;
    }

    if (indexPath.section == 2 && indexPath.row == 1) {
        NSArray *nombres = @[@"Más recientes", @"Título", @"Autor", @"Fecha de alta"];
        NSMutableArray *acciones = [NSMutableArray array];
        for (NSInteger i = 0; i < nombres.count; i++) {
            BOOL sel = (ajustes.librarySort == (IRLibrarySortKey)i);
            [acciones addObject:[IRDialogAction actionWithTitle:(sel ? [@"\u2713 " stringByAppendingString:nombres[(NSUInteger)i]] : nombres[(NSUInteger)i])
                                                          style:(sel ? IRDialogActionStyleSelected : IRDialogActionStyleDefault)
                                                        handler:^{
                ajustes.librarySort = (IRLibrarySortKey)i;
                [ajustes save];
                [tableView reloadData];
                [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
            }]];
        }
        [IRDialog showSheetIn:self title:@"Ordenar por" actions:acciones];
        return;
    }

    if (indexPath.section == 4) {
        [IRDialog showPromptIn:self title:@"Puerto del servidor"
                       message:@"Elige un puerto entre 1024 y 65535. Necesario reiniciar el servidor."
                   placeholder:@"8080" text:[NSString stringWithFormat:@"%ld", (long)ajustes.wifiPort]
                       handler:^(NSString *texto) {
            NSInteger puerto = [texto integerValue];
            if (puerto < 1024 || puerto > 65535) {
                [IRDialog showAlertIn:self title:@"Puerto no válido"
                              message:@"Usa un número entre 1024 y 65535."];
                return;
            }
            ajustes.wifiPort = puerto;
            [ajustes save];
            [tableView reloadData];
            [IRToast showIn:self.view message:@"Puerto actualizado"];
        }];
        return;
    }

    if (indexPath.section == 5 && indexPath.row == 0) {
        [IRDialog showConfirmIn:self title:@"Restablecer ajustes"
                        message:@"Se restaurarán el tema, la tipografía y los márgenes de lectura."
                    destructive:YES confirmTitle:@"Restablecer" handler:^{
            [ajustes resetReadingDefaults];
            [IRTheme shared].readingTheme = ajustes.readingTheme;
            [tableView reloadData];
            [IRToast showIn:self.view message:@"Ajustes restablecidos"];
        }];
        return;
    }

    if (indexPath.section == 5 && indexPath.row == 1) {
        [IRDialog showConfirmIn:self title:@"Vaciar caché"
                        message:@"Se eliminarán las portadas temporales, los EPUB extraídos y las miniaturas. Tus documentos no se tocan."
                    destructive:YES confirmTitle:@"Vaciar" handler:^{
            NSString *cache = [IRUtils cachesPath];
            NSArray *contenido = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cache error:NULL];
            for (NSString *n in contenido) {
                [[NSFileManager defaultManager] removeItemAtPath:[cache stringByAppendingPathComponent:n] error:NULL];
            }
            for (IRDocument *d in [IRLibrary shared].documents) {
                d.coverName = @"";
            }
            [[IRLibrary shared] save];
            [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
            [IRToast showIn:self.view message:@"Caché vaciada"];
        }];
        return;
    }

    if (indexPath.section == 6 && indexPath.row == 1) {
        [IRDialog showAlertIn:self title:@"Licencia"
                      message:@"IReader 1.0.0 · MIT License.\n\nLector y biblioteca creados por Loftur. Usa CGPDF, TextKit, WebKit, zlib y AVFoundation de Apple. Consulta THIRD_PARTY_NOTICES.md en el repositorio para los créditos completos."];
    }
}

#pragma mark - Controles

- (void)switchChanged:(UISwitch *)sw {
    IRSettings *a = [IRSettings shared];
    NSInteger section = sw.tag / 100;
    NSInteger row = sw.tag % 100;
    if (section == 0) {
        a.appDark = sw.on;
        [IRTheme applyDark:sw.on];
    } else if (section == 1) {
        if (row == 5) a.readingJustify = sw.on;
        else if (row == 6) a.readingHyphenate = sw.on;
        else if (row == 7) a.originalLayout = sw.on;
        else if (row == 9) a.lockScrollAxis = sw.on;
    } else if (section == 2) {
        if (row == 2) a.librarySortAscending = sw.on;
        else if (row == 3) a.showProgressBars = sw.on;
        else if (row == 4) a.showOnlyReading = sw.on;
    } else if (section == 3) {
        a.keepAwake = sw.on;
        [UIApplication sharedApplication].idleTimerDisabled = sw.on;
    }
    [a save];
    [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
}

- (void)stepperChanged:(UIStepper *)st {
    [IRSettings shared].readingFontSize = st.value;
    [[IRSettings shared] save];
    [self.tableView reloadData];
}

- (void)sliderChanged:(UISlider *)slider {
    IRSettings *a = [IRSettings shared];
    NSInteger section = slider.tag / 100;
    NSInteger row = slider.tag % 100;
    if (section == 1) {
        if (row == 3) a.readingLineSpacing = slider.value;
        else if (row == 4) a.readingMargin = slider.value;
    } else if (section == 3) {
        a.readingBrightness = slider.value;
    }
    [a save];
}

- (void)readingThemeChanged:(UISegmentedControl *)seg {
    [IRSettings shared].readingTheme = (IRReadingTheme)seg.selectedSegmentIndex;
    [IRTheme shared].readingTheme = (IRReadingTheme)seg.selectedSegmentIndex;
    [[IRSettings shared] save];
}

- (void)libraryViewChanged:(UISegmentedControl *)seg {
    [IRSettings shared].libraryView = (IRLibraryViewMode)seg.selectedSegmentIndex;
    [[IRSettings shared] save];
    [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
}

- (void)accentTapped:(UIButton *)sender {
    [IRSettings shared].accentIndex = sender.tag;
    [[IRSettings shared] save];
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:IRThemeDidChangeNotification object:[IRTheme shared]];
    [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:nil];
}

@end
