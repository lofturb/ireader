#import "IRBookCell.h"
#import "IRTheme.h"
#import "IRIcons.h"
#import "IRUtils.h"
#import "IRSettings.h"

static NSCache *IRCoverCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 160;
    });
    return cache;
}

@interface IRBookCell ()
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UIView *coverFrame;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *favoriteView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) IRDocument *document;
@end

@implementation IRBookCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [IRTheme shared].cardBackground;
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [IRTheme shared].separator.CGColor;
        self.clipsToBounds = NO;

        _coverFrame = [[UIView alloc] init];
        _coverFrame.backgroundColor = [IRTheme shared].controlFill;
        _coverFrame.layer.cornerRadius = 8;
        _coverFrame.clipsToBounds = YES;
        [self.contentView addSubview:_coverFrame];

        _coverView = [[UIImageView alloc] init];
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        _coverView.clipsToBounds = YES;
        [_coverFrame addSubview:_coverView];

        _badgeLabel = [[UILabel alloc] init];
        _badgeLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.backgroundColor = [[IRTheme shared].textPrimary colorWithAlphaComponent:0.72];
        _badgeLabel.layer.cornerRadius = 4;
        _badgeLabel.clipsToBounds = YES;
        [_coverFrame addSubview:_badgeLabel];

        _favoriteView = [[UIImageView alloc] init];
        _favoriteView.contentMode = UIViewContentModeScaleAspectFit;
        [_coverFrame addSubview:_favoriteView];

        _progressTrack = [[UIView alloc] init];
        _progressTrack.backgroundColor = [[IRTheme shared].textPrimary colorWithAlphaComponent:0.16];
        [_coverFrame addSubview:_progressTrack];

        _progressFill = [[UIView alloc] init];
        _progressFill.backgroundColor = [IRTheme shared].accent;
        [_progressTrack addSubview:_progressFill];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [IRTheme shared].textPrimary;
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];

        _authorLabel = [[UILabel alloc] init];
        _authorLabel.font = [IRTheme shared].fontCaption;
        _authorLabel.textColor = [IRTheme shared].textSecondary;
        _authorLabel.numberOfLines = 1;
        [self.contentView addSubview:_authorLabel];

        _progressLabel = [[UILabel alloc] init];
        _progressLabel.font = [UIFont systemFontOfSize:11];
        _progressLabel.textColor = [IRTheme shared].textTertiary;
        [self.contentView addSubview:_progressLabel];

        _chevronView = [[UIImageView alloc] init];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        _chevronView.image = [IRIcons icon:IRGlyphChevronRight size:16 color:[IRTheme shared].textTertiary];
        [self.contentView addSubview:_chevronView];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.coverView.image = nil;
    self.document = nil;
    self.titleLabel.text = nil;
    self.authorLabel.text = nil;
    self.progressLabel.text = nil;
}

- (void)configureWithDocument:(IRDocument *)document {
    self.document = document;
    self.titleLabel.text = document.title.length ? document.title : @"Sin tÃ­tulo";
    self.authorLabel.text = document.displayAuthor;

    UIImage *portada = nil;
    if (document.coverName.length) {
        NSString *ruta = [document coverPath];
        NSString *clave = [NSString stringWithFormat:@"%@|%@", ruta, document.identifier ?: @""];
        portada = [IRCoverCache() objectForKey:clave];
        if (!portada) {
            portada = [IRUtils downsampleImageAtPath:ruta maxPixelSize:640];
            if (portada) [IRCoverCache() setObject:portada forKey:clave];
        }
    }
    if (!portada) {
        CGSize tam = self.gridMode ? CGSizeMake(320, 440) : CGSizeMake(160, 220);
        portada = [IRBookCell coverImageForDocument:document size:tam];
    }
    self.coverView.image = portada;

    self.badgeLabel.text = [IRUtils typeName:document.type].uppercaseString;
    self.badgeLabel.hidden = !self.gridMode;
    self.favoriteView.image = document.favorite
        ? [IRIcons icon:IRGlyphStarFill size:14 color:[IRTheme shared].warning]
        : nil;
    self.favoriteView.hidden = !document.favorite;

    double fraccion = [document.progress fraction];
    self.progressFill.hidden = !([IRSettings shared].showProgressBars && fraccion > 0.001);
    self.progressTrack.hidden = self.progressFill.hidden;
    self.progressFill.frame = CGRectMake(0, 0,
        MAX(0, self.progressTrack.bounds.size.width * fraccion),
        self.progressTrack.bounds.size.height);
    self.progressLabel.text = [document pageLabel];
    self.progressLabel.hidden = (document.progress.pageCount <= 0 && fraccion <= 0.001);
    self.chevronView.hidden = self.gridMode;

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@. %@",
                               self.titleLabel.text, self.authorLabel.text, self.progressLabel.text ?: @""];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat p = 10;

    if (self.gridMode) {
        if (self.progressTrack.superview != self.coverFrame) {
            [self.coverFrame addSubview:self.progressTrack];
        }
        CGFloat coverH = MAX(60, h - 58);
        self.coverFrame.frame = CGRectMake(p, p, w - p * 2, coverH - p);
        self.coverView.frame = self.coverFrame.bounds;
        self.badgeLabel.frame = CGRectMake(6, 6, MIN(70, self.coverFrame.bounds.size.width - 32), 15);
        self.favoriteView.frame = CGRectMake(self.coverFrame.bounds.size.width - 22, 5, 16, 16);
        self.progressTrack.frame = CGRectMake(0, self.coverFrame.bounds.size.height - 4,
                                              self.coverFrame.bounds.size.width, 4);
        self.progressFill.frame = CGRectMake(0, 0,
            self.progressTrack.bounds.size.width * MAX(0, MIN(1, [self.document.progress fraction])),
            4);

        CGFloat y = CGRectGetMaxY(self.coverFrame.frame) + 6;
        self.titleLabel.frame = CGRectMake(p, y, w - p * 2, 34);
        self.authorLabel.frame = CGRectMake(p, y + 35, w - p * 2, 15);
        self.progressLabel.frame = CGRectZero;
        self.chevronView.frame = CGRectZero;
    } else {
        if (self.progressTrack.superview != self.contentView) {
            [self.contentView addSubview:self.progressTrack];
        }
        CGFloat coverW = 52;
        CGFloat coverH = MIN(72, h - 16);
        self.coverFrame.frame = CGRectMake(p, (h - coverH) / 2, coverW, coverH);
        self.coverView.frame = self.coverFrame.bounds;
        self.badgeLabel.frame = CGRectZero;
        self.favoriteView.frame = CGRectMake(3, 3, 12, 12);

        CGFloat x = CGRectGetMaxX(self.coverFrame.frame) + 12;
        CGFloat ancho = w - x - 30;
        self.titleLabel.frame = CGRectMake(x, 12, ancho, 22);
        self.authorLabel.frame = CGRectMake(x, 34, ancho, 16);
        self.progressLabel.frame = CGRectMake(x, 54, ancho, 14);
        self.progressTrack.frame = CGRectMake(x, 74, ancho, 3);
        self.progressFill.frame = CGRectMake(0, 0,
            self.progressTrack.bounds.size.width * MAX(0, MIN(1, [self.document.progress fraction])),
            3);
        self.chevronView.frame = CGRectMake(w - 24, (h - 16) / 2, 16, 16);
    }
}

+ (UIImage *)coverImageForDocument:(IRDocument *)document size:(CGSize)size {
    if (size.width < 1 || size.height < 1) return nil;
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *base = [IRTheme colorFromSeed:document.coverSeed];
    [base setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));

    // Textura discreta: lineas horizontales suaves.
    [[UIColor colorWithWhite:1 alpha:0.06] setFill];
    for (CGFloat y = 0; y < size.height; y += 7) {
        CGContextFillRect(ctx, CGRectMake(0, y, size.width, 1));
    }
    // Lomo del libro.
    [[UIColor colorWithWhite:0 alpha:0.16] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, MAX(4, size.width * 0.035), size.height));
    [[UIColor colorWithWhite:1 alpha:0.14] setFill];
    CGContextFillRect(ctx, CGRectMake(MAX(4, size.width * 0.035), 0, 1, size.height));

    CGFloat margen = size.width * 0.12;
    CGRect caja = CGRectMake(margen, size.height * 0.12,
                             size.width - margen * 2, size.height * 0.76);

    NSString *tipo = [IRUtils typeName:document.type].uppercaseString;
    NSDictionary *attrsTipo = @{
        NSFontAttributeName: [UIFont systemFontOfSize:MAX(8, size.width * 0.045) weight:UIFontWeightBold],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.72]
    };
    [tipo drawAtPoint:CGPointMake(caja.origin.x, caja.origin.y) withAttributes:attrsTipo];

    NSString *titulo = document.title.length ? document.title : @"Sin tÃ­tulo";
    UIFont *fuente = [UIFont fontWithName:@"Georgia-Bold" size:MAX(11, size.width * 0.085)]
                     ?: [UIFont boldSystemFontOfSize:MAX(11, size.width * 0.085)];
    NSMutableParagraphStyle *parrafo = [[NSMutableParagraphStyle alloc] init];
    parrafo.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attrsTitulo = @{
        NSFontAttributeName: fuente,
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.96],
        NSParagraphStyleAttributeName: parrafo
    };
    CGRect rectTitulo = CGRectMake(caja.origin.x, size.height * 0.30,
                                   caja.size.width, size.height * 0.40);
    [titulo drawWithRect:rectTitulo options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
              attributes:attrsTitulo context:nil];

    NSString *autor = document.author.length ? document.author : @"IReader";
    NSDictionary *attrsAutor = @{
        NSFontAttributeName: [UIFont systemFontOfSize:MAX(8, size.width * 0.048)],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.72]
    };
    [autor drawWithRect:CGRectMake(caja.origin.x, size.height * 0.80, caja.size.width, size.height * 0.10)
                options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
             attributes:attrsAutor context:nil];

    // Filete inferior.
    [[UIColor colorWithWhite:1 alpha:0.34] setFill];
    CGContextFillRect(ctx, CGRectMake(caja.origin.x, size.height * 0.76, caja.size.width * 0.32, MAX(1, size.height * 0.004)));

    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imagen;
}

@end
