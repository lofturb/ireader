#import "IRWiFiViewController.h"
#import "IRHTTPServer.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRIcons.h"
#import "IRDialog.h"
#import "IRImportManager.h"
#import <CoreImage/CoreImage.h>

@interface IRWiFiViewController ()

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *badgeView;
@property (nonatomic, strong) UIImageView *badgeIcon;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *urlLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *qrView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation IRWiFiViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.background;

    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = tema.elevatedBackground;
    [self.view addSubview:self.topBar];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"Wi-Fi";
    self.titleLabel.font = tema.fontHeadline;
    self.titleLabel.textColor = tema.textPrimary;
    [self.topBar addSubview:self.titleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setImage:[IRIcons icon:IRGlyphClose size:20 color:tema.textPrimary]
                      forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeTapped:)
               forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.card = [[UIView alloc] init];
    self.card.backgroundColor = tema.cardBackground;
    self.card.layer.cornerRadius = tema.largeCornerRadius;
    self.card.layer.borderWidth = 1;
    self.card.layer.borderColor = tema.separator.CGColor;
    [self.scrollView addSubview:self.card];

    self.badgeView = [[UIView alloc] init];
    self.badgeView.backgroundColor = tema.accentSoft;
    self.badgeView.layer.cornerRadius = 32;
    [self.card addSubview:self.badgeView];

    self.badgeIcon = [[UIImageView alloc] init];
    self.badgeIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.badgeView addSubview:self.badgeIcon];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.font = tema.fontBody;
    self.hintLabel.textColor = tema.textPrimary;
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    [self.card addSubview:self.hintLabel];

    self.urlLabel = [[UILabel alloc] init];
    self.urlLabel.font = [tema fontMono:17];
    self.urlLabel.textColor = tema.accent;
    self.urlLabel.textAlignment = NSTextAlignmentCenter;
    self.urlLabel.numberOfLines = 2;
    self.urlLabel.adjustsFontSizeToFitWidth = YES;
    self.urlLabel.minimumScaleFactor = 0.6;
    [self.card addSubview:self.urlLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = tema.fontCaption;
    self.statusLabel.textColor = tema.textSecondary;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.card addSubview:self.statusLabel];

    self.qrView = [[UIImageView alloc] init];
    self.qrView.contentMode = UIViewContentModeScaleAspectFit;
    [self.card addSubview:self.qrView];

    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.layer.cornerRadius = 10;
    self.toggleButton.titleLabel.font = tema.fontHeadline;
    [self.toggleButton addTarget:self action:@selector(toggleTapped:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.toggleButton];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.font = tema.fontCaption;
    self.footerLabel.textColor = tema.textTertiary;
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    self.footerLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.footerLabel];

    [self updateUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startServerIfNeeded];
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self
                                                selector:@selector(tick)
                                                userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)dealloc {
    [_timer invalidate];
}

- (void)tick {
    [self updateUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat top = [IRUtils statusBarHeight];
    CGFloat padding = MIN(40, w * 0.06);

    self.topBar.frame = CGRectMake(0, 0, w, top + 52);
    self.titleLabel.frame = CGRectMake(20, top + 15, w - 80, 22);
    self.closeButton.frame = CGRectMake(w - 48, top + 10, 36, 36);

    CGFloat ancho = MIN(520, w - padding * 2);
    CGFloat x = (w - ancho) / 2;
    self.scrollView.frame = CGRectMake(0, top + 52, w, h - top - 52);

    CGFloat interior = 22;
    CGFloat anchoInterior = ancho - interior * 2;
    CGFloat y = 26;

    self.badgeView.frame = CGRectMake((ancho - 64) / 2, y, 64, 64);
    self.badgeIcon.frame = CGRectMake(16, 16, 32, 32);
    y += 82;

    CGFloat altoPista = [self.hintLabel sizeThatFits:
                         CGSizeMake(anchoInterior, CGFLOAT_MAX)].height;
    self.hintLabel.frame = CGRectMake(interior, y, anchoInterior, altoPista);
    y += altoPista + 16;

    self.urlLabel.frame = CGRectMake(interior, y, anchoInterior, 52);
    y += 58;

    self.statusLabel.frame = CGRectMake(interior, y, anchoInterior, 34);
    y += 42;

    self.qrView.frame = CGRectMake((ancho - 168) / 2, y, 168, 168);
    y += 182;

    self.toggleButton.frame = CGRectMake(interior, y, anchoInterior, 46);
    y += 64;

    self.card.frame = CGRectMake(x, 24, ancho, y);

    CGSize pie = [self.footerLabel sizeThatFits:CGSizeMake(anchoInterior, CGFLOAT_MAX)];
    self.footerLabel.frame = CGRectMake(interior, CGRectGetMaxY(self.card.frame) + 18,
                                        anchoInterior, pie.height);
    self.scrollView.contentSize = CGSizeMake(w, CGRectGetMaxY(self.footerLabel.frame) + 30);
}

#pragma mark - Servidor

- (void)startServerIfNeeded {
    IRHTTPServer *servidor = [IRHTTPServer shared];
    if (servidor.running) return;
    __weak typeof(self) debil = self;
    servidor.onFileUploaded = ^(NSString *ruta) {
        __strong typeof(debil) fuerte = debil;
        if (!fuerte) return;
        [fuerte recibidoArchivo:ruta];
    };
    BOOL arrancado = [servidor startOnPort:[IRSettings shared].wifiPort
                          uploadsDirectory:[IRUtils uploadsPath]];
    if (!arrancado) {
        [IRToast showIn:self.view message:@"No se pudo abrir el puerto. Prueba otro en Ajustes."];
    }
    [self updateUI];
}

- (void)recibidoArchivo:(NSString *)ruta {
    if (!ruta.length) return;
    [[IRImportManager shared] importFileAtPath:ruta move:YES completion:^(IRDocument *doc, NSError *error) {
        if (doc) {
            [IRToast showIn:self.view message:[NSString stringWithFormat:@"Recibido: %@", doc.title]];
        } else if (error) {
            [IRToast showIn:self.view message:error.localizedDescription];
        }
    }];
    if (self.onImport) self.onImport(@[ruta]);
}

- (void)updateUI {
    IRHTTPServer *servidor = [IRHTTPServer shared];
    NSString *url = servidor.bestURL;
    self.urlLabel.text = url;
    self.statusLabel.text = servidor.running
        ? [NSString stringWithFormat:@"Servidor activo en el puerto %ld", (long)servidor.port]
        : @"Servidor detenido";

    if (servidor.running) {
        [self.toggleButton setTitle:@"Detener servidor" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [IRTheme shared].controlFill;
        [self.toggleButton setTitleColor:[IRTheme shared].textPrimary forState:UIControlStateNormal];
        self.qrView.image = [self qrForString:url];
        self.hintLabel.text = @"Abre esta dirección en el navegador de tu ordenador. Arrastra ahí tus documentos o pulsa «Elegir archivos».";
    } else {
        [self.toggleButton setTitle:@"Iniciar servidor" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [IRTheme shared].accent;
        [self.toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.qrView.image = nil;
        self.hintLabel.text = @"Inicia el servidor y conéctate desde el ordenador al mismo Wi-Fi del iPad para enviar tus documentos.";
    }
    self.footerLabel.text = @"El servidor solo funciona con la app en primer plano. Puedes usar el código QR o teclear la dirección.";
    self.badgeIcon.image = [IRIcons icon:IRGlyphWifi size:32 color:[IRTheme shared].accent];
    [self.view setNeedsLayout];
}

- (UIImage *)qrForString:(NSString *)texto {
    if (!texto.length) return nil;
    NSData *datos = [texto dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filtro = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filtro setValue:datos forKey:@"inputMessage"];
    [filtro setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *imagen = filtro.outputImage;
    if (!imagen) return nil;
    CGSize tam = CGSizeMake(168, 168);
    CGFloat escala = MIN(tam.width / imagen.extent.size.width,
                         tam.height / imagen.extent.size.height);
    CIImage *escalada = [imagen imageByApplyingTransform:CGAffineTransformMakeScale(escala, escala)];
    CIContext *contexto = [CIContext contextWithOptions:nil];
    CGImageRef cg = [contexto createCGImage:escalada fromRect:escalada.extent];
    if (!cg) return nil;
    UIGraphicsBeginImageContextWithOptions(tam, YES, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, tam.width, tam.height));
    CGContextDrawImage(ctx, CGRectMake(0, 0, tam.width, tam.height), cg);
    UIImage *salida = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(cg);
    return salida;
}

- (void)toggleTapped:(UIButton *)sender {
    IRHTTPServer *servidor = [IRHTTPServer shared];
    if (servidor.running) {
        [servidor stop];
        [IRToast showIn:self.view message:@"Servidor detenido"];
    } else {
        [self startServerIfNeeded];
        [IRToast showIn:self.view message:@"Servidor iniciado"];
    }
    [self updateUI];
}

- (void)closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
