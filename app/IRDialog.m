#import "IRDialog.h"
#import "IRTheme.h"
#import "IRIcons.h"
#import "IRUtils.h"

#pragma mark - IRDialogAction

@implementation IRDialogAction
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(IRDialogActionStyle)style
                        handler:(void (^)(void))handler {
    IRDialogAction *a = [[IRDialogAction alloc] init];
    a.title = title ?: @"";
    a.style = style;
    a.enabled = YES;
    a.handler = handler;
    return a;
}
@end

#pragma mark - IRDialog

@interface IRDialog () <UITextFieldDelegate>
@property (nonatomic, copy) NSString *dialogTitle;
@property (nonatomic, copy) NSString *dialogMessage;
@property (nonatomic, strong) NSMutableArray<IRDialogAction *> *mutableActions;
@property (nonatomic, strong) NSMutableArray<UITextField *> *mutableFields;
@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, assign) BOOL dismissing;
@end

@implementation IRDialog

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message {
    IRDialog *d = [[IRDialog alloc] init];
    d.style = IRDialogStyleAlert;
    d.dialogTitle = title ?: @"";
    d.dialogMessage = message ?: @"";
    d.dismissOnTapOutside = NO;
    return d;
}

+ (instancetype)sheetWithTitle:(NSString *)title message:(NSString *)message {
    IRDialog *d = [[IRDialog alloc] init];
    d.style = IRDialogStyleSheet;
    d.dialogTitle = title ?: @"";
    d.dialogMessage = message ?: @"";
    d.dismissOnTapOutside = YES;
    return d;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableActions = [NSMutableArray array];
        _mutableFields = [NSMutableArray array];
        _buttons = [NSMutableArray array];
        _dismissOnTapOutside = YES;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (NSArray<IRDialogAction *> *)actions { return [self.mutableActions copy]; }
- (NSArray<UITextField *> *)textFields { return [self.mutableFields copy]; }

- (IRDialogAction *)addAction:(NSString *)title
                        style:(IRDialogActionStyle)style
                      handler:(void (^)(void))handler {
    IRDialogAction *a = [IRDialogAction actionWithTitle:title style:style handler:handler];
    [self.mutableActions addObject:a];
    return a;
}

- (UITextField *)addTextFieldWithPlaceholder:(NSString *)placeholder
                                        text:(NSString *)text
                                      secure:(BOOL)secure {
    UITextField *f = [[UITextField alloc] init];
    f.placeholder = placeholder;
    f.text = text;
    f.secureTextEntry = secure;
    f.font = [IRTheme shared].fontBody;
    f.textColor = [IRTheme shared].textPrimary;
    f.backgroundColor = [IRTheme shared].fieldBackground;
    f.layer.cornerRadius = 8;
    f.layer.borderWidth = 1;
    f.layer.borderColor = [IRTheme shared].separator.CGColor;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.delegate = self;
    f.returnKeyType = UIReturnKeyDone;
    [self.mutableFields addObject:f];
    return f;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    self.overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlay.backgroundColor = [IRTheme shared].overlay;
    [self.view addSubview:self.overlay];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(overlayTapped:)];
    [self.overlay addGestureRecognizer:tap];

    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [IRTheme shared].elevatedBackground;
    self.card.layer.cornerRadius = [IRTheme shared].largeCornerRadius;
    self.card.layer.shadowColor = [UIColor blackColor].CGColor;
    self.card.layer.shadowOpacity = 0.18;
    self.card.layer.shadowRadius = 24;
    self.card.layer.shadowOffset = CGSizeMake(0, 10);
    [self.view addSubview:self.card];

    if (self.dialogTitle.length) {
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.text = self.dialogTitle;
        self.titleLabel.font = [IRTheme shared].fontHeadline;
        self.titleLabel.textColor = [IRTheme shared].textPrimary;
        self.titleLabel.numberOfLines = 0;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.card addSubview:self.titleLabel];
    }
    if (self.dialogMessage.length) {
        self.messageLabel = [[UILabel alloc] init];
        self.messageLabel.text = self.dialogMessage;
        self.messageLabel.font = [IRTheme shared].fontBody;
        self.messageLabel.textColor = [IRTheme shared].textSecondary;
        self.messageLabel.numberOfLines = 0;
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        [self.card addSubview:self.messageLabel];
    }
    for (UITextField *f in self.mutableFields) [self.card addSubview:f];

    for (IRDialogAction *a in self.mutableActions) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.titleLabel.font = [IRTheme shared].fontHeadline;
        [b setTitle:a.title forState:UIControlStateNormal];
        b.layer.cornerRadius = 9;
        b.tag = [self.mutableActions indexOfObject:a];
        switch (a.style) {
            case IRDialogActionStyleSelected:
                b.backgroundColor = [IRTheme shared].accent;
                [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                break;
            case IRDialogActionStyleDestructive:
                b.backgroundColor = [[IRTheme shared].danger colorWithAlphaComponent:0.12];
                [b setTitleColor:[IRTheme shared].danger forState:UIControlStateNormal];
                break;
            case IRDialogActionStyleCancel:
                b.backgroundColor = [UIColor clearColor];
                [b setTitleColor:[IRTheme shared].textSecondary forState:UIControlStateNormal];
                break;
            default:
                b.backgroundColor = [IRTheme shared].controlFill;
                [b setTitleColor:[IRTheme shared].textPrimary forState:UIControlStateNormal];
                break;
        }
        b.enabled = a.enabled;
        if (!a.enabled) b.alpha = 0.45;
        [b addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.card addSubview:b];
        [self.buttons addObject:b];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];

    self.card.alpha = 0;
    self.overlay.alpha = 0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UIView animateWithDuration:0.20 animations:^{
        self.overlay.alpha = 1;
        self.card.alpha = 1;
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutDialog];
}

- (void)layoutDialog {
    CGFloat pantallaW = self.view.bounds.size.width;
    CGFloat pantallaH = self.view.bounds.size.height;
    CGFloat padding = 20;
    BOOL alerta = (self.style == IRDialogStyleAlert);
    CGFloat ancho = alerta ? MIN(430, pantallaW - 48) : pantallaW;
    CGFloat contenidoW = ancho - padding * 2;
    CGFloat y = padding;

    if (self.titleLabel) {
        CGSize s = [self.titleLabel sizeThatFits:CGSizeMake(contenidoW, CGFLOAT_MAX)];
        self.titleLabel.frame = CGRectMake(padding, y, contenidoW, s.height);
        y += s.height + 8;
    }
    if (self.messageLabel) {
        CGSize s = [self.messageLabel sizeThatFits:CGSizeMake(contenidoW, CGFLOAT_MAX)];
        self.messageLabel.frame = CGRectMake(padding, y, contenidoW, s.height);
        y += s.height + 14;
    }
    for (UITextField *f in self.mutableFields) {
        f.frame = CGRectMake(padding, y, contenidoW, 44);
        y += 44 + 10;
    }
    if (self.mutableFields.count) y += 2;

    CGFloat altoBoton = 48;
    for (UIButton *b in self.buttons) {
        b.frame = CGRectMake(padding, y, contenidoW, altoBoton);
        y += altoBoton + 8;
    }
    y += 4;

    CGFloat alto = y;
    CGFloat x = (pantallaW - ancho) / 2;
    CGFloat cardY;
    if (alerta) {
        cardY = MAX(24, (pantallaH - alto) / 2 - self.keyboardHeight / 2);
    } else {
        cardY = pantallaH - alto - 12;
        if (self.keyboardHeight > 0) cardY -= self.keyboardHeight;
        cardY = MAX(20, cardY);
    }
    self.card.frame = CGRectMake(x, cardY, ancho, alto);
    self.card.layer.cornerRadius = alerta ? [IRTheme shared].largeCornerRadius : 18;
}

- (void)overlayTapped:(UITapGestureRecognizer *)tap {
    if (!self.dismissOnTapOutside) return;
    [self dismissWithHandler:nil];
}

- (void)actionTapped:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.mutableActions.count) return;
    IRDialogAction *a = self.mutableActions[(NSUInteger)sender.tag];
    if (!a.enabled) return;
    [self dismissWithHandler:a.handler];
}

- (void)dismissWithHandler:(void (^)(void))handler {
    if (self.dismissing) return;
    self.dismissing = YES;
    [UIView animateWithDuration:0.16 animations:^{
        self.overlay.alpha = 0;
        self.card.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:^{
            if (handler) handler();
        }];
    }];
}

- (void)presentIn:(UIViewController *)viewController {
    if (!viewController) return;
    UIViewController *presentador = viewController;
    while (presentador.presentedViewController &&
           !presentador.presentedViewController.isBeingDismissed) {
        presentador = presentador.presentedViewController;
    }
    [presentador presentViewController:self animated:NO completion:nil];
}

- (void)keyboardWillChange:(NSNotification *)note {
    CGRect fin = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect enVentana = [self.view convertRect:fin fromView:nil];
    CGFloat solape = MAX(0, self.view.bounds.size.height - enVentana.origin.y);
    self.keyboardHeight = solape;
    [UIView animateWithDuration:0.22 animations:^{
        [self layoutDialog];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Atajos

+ (void)showAlertIn:(UIViewController *)vc title:(NSString *)title message:(NSString *)message {
    IRDialog *d = [IRDialog alertWithTitle:title message:message];
    [d addAction:@"Entendido" style:IRDialogActionStyleSelected handler:nil];
    [d presentIn:vc];
}

+ (void)showErrorIn:(UIViewController *)vc error:(NSError *)error {
    NSString *msg = error.localizedDescription ?: @"Ha ocurrido un problema.";
    [self showAlertIn:vc title:@"No se pudo completar" message:msg];
}

+ (void)showConfirmIn:(UIViewController *)vc
                title:(NSString *)title
              message:(NSString *)message
          destructive:(BOOL)destructive
         confirmTitle:(NSString *)confirmTitle
              handler:(void (^)(void))handler {
    IRDialog *d = [IRDialog alertWithTitle:title message:message];
    [d addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:nil];
    [d addAction:confirmTitle ?: @"Aceptar"
           style:destructive ? IRDialogActionStyleDestructive : IRDialogActionStyleSelected
         handler:handler];
    [d presentIn:vc];
}

+ (void)showSheetIn:(UIViewController *)vc
              title:(NSString *)title
            actions:(NSArray<IRDialogAction *> *)actions {
    IRDialog *d = [IRDialog sheetWithTitle:title message:nil];
    for (IRDialogAction *a in actions) {
        [d addAction:a.title style:a.style handler:a.handler];
    }
    [d addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:nil];
    [d presentIn:vc];
}

+ (void)showPromptIn:(UIViewController *)vc
               title:(NSString *)title
             message:(NSString *)message
         placeholder:(NSString *)placeholder
                text:(NSString *)text
             handler:(void (^)(NSString *text))handler {
    IRDialog *d = [IRDialog alertWithTitle:title message:message];
    d.dismissOnTapOutside = NO;
    UITextField *f = [d addTextFieldWithPlaceholder:placeholder text:text secure:NO];
    [d addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:nil];
    [d addAction:@"Guardar" style:IRDialogActionStyleSelected handler:^{
        if (handler) handler(f.text ?: @"");
    }];
    [d presentIn:vc];
}

+ (void)showPasswordIn:(UIViewController *)vc
                 title:(NSString *)title
               message:(NSString *)message
               handler:(void (^)(NSString *password))handler {
    IRDialog *d = [IRDialog alertWithTitle:title message:message];
    d.dismissOnTapOutside = NO;
    UITextField *f = [d addTextFieldWithPlaceholder:@"Contraseña" text:@"" secure:YES];
    [d addAction:@"Cancelar" style:IRDialogActionStyleCancel handler:nil];
    [d addAction:@"Abrir" style:IRDialogActionStyleSelected handler:^{
        if (handler) handler(f.text ?: @"");
    }];
    [d presentIn:vc];
}

@end

#pragma mark - IRToast

@implementation IRToast

+ (void)showIn:(UIView *)view message:(NSString *)message {
    [self showIn:view message:message icon:nil];
}

+ (void)showIn:(UIView *)view message:(NSString *)message icon:(UIImage *)icon {
    if (!view || !message.length) return;
    for (UIView *v in view.subviews) {
        if ([v isKindOfClass:[IRToast class]]) [v removeFromSuperview];
    }
    IRToast *toast = [[IRToast alloc] init];
    toast.backgroundColor = [IRTheme shared].dark ? [IRTheme colorWithHex:0x3A342B alpha:0.98]
                                                  : [IRTheme colorWithHex:0x2A251F alpha:0.96];
    toast.layer.cornerRadius = 12;
    toast.layer.shadowColor = [UIColor blackColor].CGColor;
    toast.layer.shadowOpacity = 0.20;
    toast.layer.shadowRadius = 16;
    toast.layer.shadowOffset = CGSizeMake(0, 6);

    CGFloat x = 14;
    UIImageView *iv = nil;
    if (icon) {
        iv = [[UIImageView alloc] initWithImage:icon];
        iv.frame = CGRectMake(x, 11, 20, 20);
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [toast addSubview:iv];
        x += 28;
    }
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.font = [IRTheme shared].fontSubhead;
    label.textColor = [IRTheme colorWithHex:0xF6F1E7 alpha:1];
    label.numberOfLines = 2;
    CGSize max = CGSizeMake(view.bounds.size.width - 60 - x, 60);
    CGSize s = [label sizeThatFits:max];
    label.frame = CGRectMake(x, 10, s.width, s.height);
    [toast addSubview:label];

    CGFloat ancho = s.width + x + 14;
    CGFloat alto = MAX(40, s.height + 20);
    toast.frame = CGRectMake((view.bounds.size.width - ancho) / 2,
                             view.bounds.size.height - alto - 28, ancho, alto);
    toast.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    toast.alpha = 0;
    toast.transform = CGAffineTransformMakeTranslation(0, 12);
    [view addSubview:toast];
    [UIView animateWithDuration:0.20 animations:^{
        toast.alpha = 1;
        toast.transform = CGAffineTransformIdentity;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.18 animations:^{
            toast.alpha = 0;
            toast.transform = CGAffineTransformMakeTranslation(0, 8);
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

@end

#pragma mark - IRHUD

@interface IRHUD ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIView *track;
@property (nonatomic, strong) UIView *fill;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) CAShapeLayer *spinner;
@property (nonatomic, copy) void (^cancelBlock)(void);
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) BOOL indeterminate;
@end

@implementation IRHUD

+ (instancetype)showIn:(UIView *)view title:(NSString *)title cancel:(void (^)(void))cancel {
    if (!view) return nil;
    IRHUD *hud = [[IRHUD alloc] initWithFrame:view.bounds];
    hud.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    hud.backgroundColor = [IRTheme shared].overlay;
    hud.cancelBlock = cancel;
    hud.progress = -1;
    hud.indeterminate = YES;

    hud.card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 150)];
    hud.card.backgroundColor = [IRTheme shared].elevatedBackground;
    hud.card.layer.cornerRadius = 16;
    [hud addSubview:hud.card];

    hud.titleLabel = [[UILabel alloc] init];
    hud.titleLabel.text = title ?: @"Procesando";
    hud.titleLabel.font = [IRTheme shared].fontHeadline;
    hud.titleLabel.textColor = [IRTheme shared].textPrimary;
    hud.titleLabel.textAlignment = NSTextAlignmentCenter;
    [hud.card addSubview:hud.titleLabel];

    hud.detailLabel = [[UILabel alloc] init];
    hud.detailLabel.font = [IRTheme shared].fontCaption;
    hud.detailLabel.textColor = [IRTheme shared].textSecondary;
    hud.detailLabel.textAlignment = NSTextAlignmentCenter;
    hud.detailLabel.numberOfLines = 2;
    [hud.card addSubview:hud.detailLabel];

    hud.track = [[UIView alloc] init];
    hud.track.backgroundColor = [IRTheme shared].controlFill;
    hud.track.layer.cornerRadius = 3;
    [hud.card addSubview:hud.track];

    hud.fill = [[UIView alloc] init];
    hud.fill.backgroundColor = [IRTheme shared].accent;
    hud.fill.layer.cornerRadius = 3;
    [hud.track addSubview:hud.fill];

    if (cancel) {
        hud.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [hud.cancelButton setTitle:@"Cancelar" forState:UIControlStateNormal];
        [hud.cancelButton setTitleColor:[IRTheme shared].textSecondary forState:UIControlStateNormal];
        hud.cancelButton.titleLabel.font = [IRTheme shared].fontSubhead;
        [hud.cancelButton addTarget:hud action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];
        [hud.card addSubview:hud.cancelButton];
    }

    [view addSubview:hud];
    hud.alpha = 0;
    [UIView animateWithDuration:0.18 animations:^{ hud.alpha = 1; }];
    [hud setNeedsLayout];
    return hud;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = MIN(320, self.bounds.size.width - 48);
    CGFloat alto = self.cancelButton ? 168 : 142;
    self.card.frame = CGRectMake((self.bounds.size.width - ancho) / 2,
                                 (self.bounds.size.height - alto) / 2, ancho, alto);
    CGFloat p = 20;
    self.titleLabel.frame = CGRectMake(p, 18, ancho - p * 2, 24);
    self.detailLabel.frame = CGRectMake(p, 44, ancho - p * 2, 34);
    self.track.frame = CGRectMake(p, 88, ancho - p * 2, 6);
    self.fill.frame = CGRectMake(0, 0, (ancho - p * 2) * MAX(0, MIN(1, self.progress)), 6);
    self.cancelButton.frame = CGRectMake(p, alto - 44, ancho - p * 2, 32);
}

- (void)updateProgress:(double)progress text:(NSString *)text {
    self.progress = progress;
    self.indeterminate = progress < 0;
    self.detailLabel.text = text ?: @"";
    [self setNeedsLayout];
    [UIView animateWithDuration:0.12 animations:^{ [self layoutIfNeeded]; }];
}

- (void)cancelTapped:(UIButton *)sender {
    if (self.cancelBlock) self.cancelBlock();
    [self hide];
}

- (void)hide {
    [UIView animateWithDuration:0.16 animations:^{ self.alpha = 0; } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - IRBanner

@implementation IRBanner

+ (void)showIn:(UIView *)view message:(NSString *)message style:(NSInteger)style {
    if (!view || !message.length) return;
    for (UIView *v in view.subviews) {
        if ([v isKindOfClass:[IRBanner class]]) [v removeFromSuperview];
    }
    IRBanner *b = [[IRBanner alloc] init];
    UIColor *fondo = [IRTheme shared].elevatedBackground;
    UIColor *texto = [IRTheme shared].textPrimary;
    if (style == 1) { fondo = [IRTheme shared].danger; texto = [UIColor whiteColor]; }
    else if (style == 2) { fondo = [IRTheme shared].success; texto = [UIColor whiteColor]; }
    b.backgroundColor = fondo;
    b.layer.cornerRadius = 10;
    b.layer.shadowColor = [UIColor blackColor].CGColor;
    b.layer.shadowOpacity = 0.12;
    b.layer.shadowRadius = 12;
    b.layer.shadowOffset = CGSizeMake(0, 4);

    UILabel *l = [[UILabel alloc] init];
    l.text = message;
    l.font = [IRTheme shared].fontSubhead;
    l.textColor = texto;
    l.numberOfLines = 2;
    CGFloat ancho = view.bounds.size.width - 32;
    CGSize s = [l sizeThatFits:CGSizeMake(ancho - 28, 60)];
    l.frame = CGRectMake(14, 10, s.width, s.height);
    [b addSubview:l];
    b.frame = CGRectMake(16, 12, ancho, MAX(40, s.height + 20));
    b.alpha = 0;
    b.transform = CGAffineTransformMakeTranslation(0, -12);
    [view addSubview:b];
    [UIView animateWithDuration:0.20 animations:^{
        b.alpha = 1;
        b.transform = CGAffineTransformIdentity;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.18 animations:^{ b.alpha = 0; } completion:^(BOOL finished) {
            [b removeFromSuperview];
        }];
    });
}

@end
