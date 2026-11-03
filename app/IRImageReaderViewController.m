#import "IRImageReaderViewController.h"
#import "IRTheme.h"
#import "IRUtils.h"
#import "IRLibrary.h"
#import "IRDialog.h"

@interface IRImageReaderViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, assign) CGFloat fitScale;
@property (nonatomic, assign) BOOL didLayout;
@end

@implementation IRImageReaderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IRTheme shared].readingBackground;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.backgroundColor = [IRTheme shared].readingBackground;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.bouncesZoom = YES;
    [self.view addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.imageView];

    UITapGestureRecognizer *doble =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
    doble.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doble];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [IRTheme shared].fontBody;
    self.errorLabel.textColor = [IRTheme shared].readingSecondary;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification" object:nil];

    [self loadImage];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.errorLabel.frame = CGRectInset(self.view.bounds, 40, 80);
    if (!self.didLayout && self.imageView.image) {
        self.didLayout = YES;
        [self configureZoomRestore:YES];
    } else if (self.imageView.image) {
        [self adjustForSizeChange];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
}

- (void)loadImage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGSize pantalla = [UIScreen mainScreen].bounds.size;
        CGFloat maxPixel = MAX(pantalla.width, pantalla.height) * 3.0;
        UIImage *imagen = [IRUtils downsampleImageAtPath:self.document.path maxPixelSize:maxPixel];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!imagen) {
                self.errorLabel.text = @"No se pudo abrir la imagen.";
                self.errorLabel.hidden = NO;
                if (self.onFailure) self.onFailure();
                return;
            }
            self.imageView.image = imagen;
            self.imageView.frame = CGRectMake(0, 0, imagen.size.width, imagen.size.height);
            [self configureZoomRestore:YES];
            [self applyDisplaySettings];
        });
    });
}

- (void)configureZoomRestore:(BOOL)restore {
    if (!self.imageView.image) return;
    CGSize imagen = self.imageView.image.size;
    CGSize visible = self.scrollView.bounds.size;
    if (visible.width < 10) visible = self.view.bounds.size;
    CGFloat escala = MIN(visible.width / MAX(1, imagen.width),
                         visible.height / MAX(1, imagen.height));
    if (escala <= 0 || !isfinite(escala)) escala = 1;
    self.fitScale = escala;
    self.scrollView.contentSize = imagen;
    self.scrollView.minimumZoomScale = escala;
    self.scrollView.maximumZoomScale = MAX(3.0, escala * 5.0);
    self.scrollView.zoomScale = escala;
    [self centerContent];

    if (restore) {
        double factor = self.document.progress.zoom;
        if (factor > 1.01 && factor < 6) {
            self.scrollView.zoomScale = MIN(self.scrollView.maximumZoomScale,
                                            MAX(self.scrollView.minimumZoomScale,
                                                self.fitScale * factor));
            [self centerContent];
        }
        CGPoint p = self.document.progress.offset;
        if (p.x > 0.001 || p.y > 0.001) {
            [self restoreNormalizedOffset:p];
        }
    }
}

- (void)adjustForSizeChange {
    if (!self.imageView.image) return;
    CGFloat relativo = self.scrollView.zoomScale / MAX(0.0001, self.fitScale);
    CGSize imagen = self.imageView.image.size;
    CGSize visible = self.scrollView.bounds.size;
    CGFloat escala = MIN(visible.width / MAX(1, imagen.width),
                         visible.height / MAX(1, imagen.height));
    if (escala <= 0 || !isfinite(escala)) escala = 1;
    self.fitScale = escala;
    self.scrollView.minimumZoomScale = escala;
    self.scrollView.maximumZoomScale = MAX(3.0, escala * 5.0);
    self.scrollView.zoomScale = MAX(escala, MIN(self.scrollView.maximumZoomScale, escala * relativo));
    [self centerContent];
}

- (void)centerContent {
    CGFloat ix = MAX(0, (self.scrollView.bounds.size.width - self.scrollView.contentSize.width) / 2);
    CGFloat iy = MAX(0, (self.scrollView.bounds.size.height - self.scrollView.contentSize.height) / 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(iy, ix, iy, ix);
}

- (CGPoint)normalizedOffset {
    CGFloat sw = MAX(1, self.scrollView.contentSize.width - self.scrollView.bounds.size.width +
                     self.scrollView.contentInset.left + self.scrollView.contentInset.right);
    CGFloat sh = MAX(1, self.scrollView.contentSize.height - self.scrollView.bounds.size.height +
                     self.scrollView.contentInset.top + self.scrollView.contentInset.bottom);
    CGFloat x = (self.scrollView.contentOffset.x + self.scrollView.contentInset.left) / sw;
    CGFloat y = (self.scrollView.contentOffset.y + self.scrollView.contentInset.top) / sh;
    return CGPointMake(MAX(0, MIN(1, x)), MAX(0, MIN(1, y)));
}

- (void)restoreNormalizedOffset:(CGPoint)p {
    CGFloat sw = MAX(1, self.scrollView.contentSize.width - self.scrollView.bounds.size.width +
                     self.scrollView.contentInset.left + self.scrollView.contentInset.right);
    CGFloat sh = MAX(1, self.scrollView.contentSize.height - self.scrollView.bounds.size.height +
                     self.scrollView.contentInset.top + self.scrollView.contentInset.bottom);
    CGFloat x = MAX(0, MIN(1, p.x)) * sw - self.scrollView.contentInset.left;
    CGFloat y = MAX(0, MIN(1, p.y)) * sh - self.scrollView.contentInset.top;
    [self.scrollView setContentOffset:CGPointMake(x, y) animated:NO];
}

- (void)doubleTapped:(UITapGestureRecognizer *)gesto {
    if (self.scrollView.zoomScale <= self.scrollView.minimumZoomScale * 1.08) {
        CGPoint p = [gesto locationInView:self.imageView];
        CGFloat objetivo = self.scrollView.minimumZoomScale * 2.4;
        CGSize tam = CGSizeMake(self.scrollView.bounds.size.width / objetivo,
                                self.scrollView.bounds.size.height / objetivo);
        [self.scrollView zoomToRect:CGRectMake(p.x - tam.width / 2, p.y - tam.height / 2,
                                               tam.width, tam.height) animated:YES];
    } else {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerContent];
}

#pragma mark - IRReader

- (void)saveProgressNow {
    if (!self.document || !self.imageView.image) return;
    IRProgress *p = self.document.progress;
    p.page = 1;
    p.pageCount = 1;
    p.zoom = self.fitScale > 0 ? self.scrollView.zoomScale / self.fitScale : 1;
    p.offset = [self normalizedOffset];
    p.ratio = 1;
    p.finished = YES;
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel { return @"Imagen"; }
- (NSInteger)pageCount { return 1; }
- (NSInteger)currentPage { return 1; }
- (void)goToPage:(NSInteger)page { }
- (NSArray<IRTOCItem *> *)tableOfContents { return @[]; }
- (void)jumpToTOCItem:(IRTOCItem *)item { }
- (BOOL)supportsBookmarks { return NO; }
- (void)addBookmarkWithNote:(NSString *)note { }
- (BOOL)supportsSearch { return NO; }
- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *))completion {
    if (completion) completion(@[]);
}
- (void)jumpToSearchResult:(IRSearchResult *)result { }
- (void)applyDisplaySettings {
    self.view.backgroundColor = [IRTheme shared].readingBackground;
    self.scrollView.backgroundColor = [IRTheme shared].readingBackground;
    self.errorLabel.textColor = [IRTheme shared].readingSecondary;
}
- (BOOL)isPaginated { return YES; }

@end
