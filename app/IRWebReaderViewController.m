#import "IRWebReaderViewController.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRUtils.h"
#import "IRIcons.h"
#import "IRLibrary.h"
#import "IRDialog.h"
#import "IREPUBDocument.h"
#import "IRArchive.h"
#import <AVFoundation/AVFoundation.h>

// Visor de EPUB, Office, HTML/SVG y multimedia. Todo se muestra respetando el
// CSS, las fuentes y el tamano de pagina originales: WebKit carga los archivos
// tal cual estan dentro del contenedor, sin reescribir el contenido.
@interface IRWebReaderViewController () <UIWebViewDelegate>

@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UILabel *chapterLabel;

@property (nonatomic, strong) UIImageView *spinner;
@property (nonatomic, strong) UILabel *loadingLabel;

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *slides;
@property (nonatomic, assign) NSInteger chapterIndex;
@property (nonatomic, assign) BOOL isEPUB;
@property (nonatomic, assign) BOOL isOffice;
@property (nonatomic, assign) BOOL isMedia;
@property (nonatomic, assign) BOOL restoredForSlide;
@property (nonatomic, assign) BOOL finished;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *mediaBar;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) NSTimer *mediaTimer;
@property (nonatomic, assign) BOOL updatingSlider;

// Interfaz y navegacion
- (void)buildTopBar;
- (void)buildLoadingViews;
- (void)hideLoading;
- (void)failWith:(NSString *)mensaje;
- (void)refreshNavigation;
- (void)showSlideAt:(NSInteger)indice;

// Carga
- (void)startLoading;
- (void)openHTML;
- (void)openEPUB;
- (void)openOffice:(NSString *)ext;
- (NSMutableArray<NSDictionary *> *)viewsForOffice:(NSString *)ext
                                      inDirectory:(NSString *)cache
                                            cache:(NSString *)root;

// Desplazamiento
- (double)currentScrollRatio;
- (void)scrollToRatio:(double)ratio;
- (NSString *)jsString:(NSString *)texto;

// Multimedia
- (void)openMedia;
- (void)buildMediaBar;
- (void)togglePlayback;
- (void)sliderChanged:(UISlider *)slider;
- (void)sliderReleased:(UISlider *)slider;
- (void)updateMediaBar;
- (void)mediaFinished:(NSNotification *)nota;

// Conversion de Office
+ (NSString *)escapeHTML:(NSString *)texto;
+ (NSString *)decodeEntities:(NSString *)texto;
+ (NSArray<NSTextCheckingResult *> *)matches:(NSString *)patron in:(NSString *)texto;
+ (NSString *)firstMatch:(NSString *)patron in:(NSString *)texto group:(NSInteger)grupo;
+ (NSString *)textFromMatches:(NSString *)patron in:(NSString *)texto group:(NSInteger)grupo;
+ (NSString *)stripTags:(NSString *)xml;
+ (NSString *)htmlDocument:(NSString *)cuerpo css:(NSString *)css ancho:(NSInteger)ancho;
+ (NSArray<NSString *> *)sharedStringsAtPath:(NSString *)ruta;
+ (NSInteger)columnIndexForReference:(NSString *)letras;
+ (NSString *)docxHTMLAtPath:(NSString *)ruta;
+ (NSString *)docxParagraphHTML:(NSString *)bloque basePt:(double)basePt;
+ (NSString *)docxTableHTML:(NSString *)bloque;
+ (NSString *)xlsxHTMLAtPath:(NSString *)ruta shared:(NSArray<NSString *> *)compartidas;
+ (CGSize)pptxSlideSizeAtPath:(NSString *)ruta;
+ (NSString *)pptxHTMLAtPath:(NSString *)ruta size:(CGSize)tamano;
+ (NSString *)openDocumentHTMLAtPath:(NSString *)ruta;

@end

@implementation IRWebReaderViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _chapterIndex = 0;
        _slides = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.readingBackground;

    self.container = [[UIView alloc] initWithFrame:self.view.bounds];
    self.container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.container.backgroundColor = tema.readingBackground;
    [self.view addSubview:self.container];

    [self buildTopBar];
    [self buildLoadingViews];
    [self refreshNavigation];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgressNow)
                                                 name:@"IRAppWillResignActiveNotification"
                                               object:nil];
    [self startLoading];
}

- (void)dealloc {
    [self.mediaTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat barra = self.topBar.hidden ? 0 : 44;

    self.topBar.frame = CGRectMake(0, 0, w, 44);
    self.prevButton.frame = CGRectMake(4, 4, 38, 36);
    self.nextButton.frame = CGRectMake(w - 42, 4, 38, 36);
    self.chapterLabel.frame = CGRectMake(46, 0, MAX(40, w - 92), 44);
    self.container.frame = CGRectMake(0, barra, w, MAX(0, h - barra));

    if (self.webView.superview == self.container) {
        self.webView.frame = self.container.bounds;
    }
    self.playerLayer.frame = self.container.bounds;
    self.spinner.center = CGPointMake(w / 2, h / 2 - 30);
    self.loadingLabel.frame = CGRectMake(30, h / 2, w - 60, 68);

    CGFloat barraMedia = 54;
    self.mediaBar.frame = CGRectMake(0, self.container.bounds.size.height - barraMedia,
                                     self.container.bounds.size.width, barraMedia);
    self.playButton.frame = CGRectMake(8, 8, 44, 38);
    self.timeLabel.frame = CGRectMake(56, 8, 110, 38);
    self.timeSlider.frame = CGRectMake(170, 8,
                                       MAX(80, self.container.bounds.size.width - 182), 38);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgressNow];
    if (self.isMedia) [self.player pause];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.mediaTimer invalidate];
    self.mediaTimer = nil;
}

#pragma mark - Interfaz

- (void)buildTopBar {
    IRTheme *tema = [IRTheme shared];
    self.topBar = [[UIView alloc] init];
    self.topBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.97];
    self.topBar.hidden = YES;
    [self.view addSubview:self.topBar];

    self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.prevButton setImage:[IRIcons icon:IRGlyphChevronLeft size:20 color:tema.textPrimary]
                     forState:UIControlStateNormal];
    [self.prevButton addTarget:self action:@selector(prevTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.prevButton];

    self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.nextButton setImage:[IRIcons icon:IRGlyphChevronRight size:20 color:tema.textPrimary]
                     forState:UIControlStateNormal];
    [self.nextButton addTarget:self action:@selector(nextTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.nextButton];

    self.chapterLabel = [[UILabel alloc] init];
    self.chapterLabel.font = tema.fontSubhead;
    self.chapterLabel.textColor = tema.textPrimary;
    self.chapterLabel.textAlignment = NSTextAlignmentCenter;
    self.chapterLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.topBar addSubview:self.chapterLabel];
}

- (void)buildLoadingViews {
    IRTheme *tema = [IRTheme shared];

    self.spinner = [[UIImageView alloc] init];
    self.spinner.image = [IRIcons icon:IRGlyphBook size:26 color:tema.textTertiary];
    [self.view addSubview:self.spinner];

    CABasicAnimation *latido = [CABasicAnimation animationWithKeyPath:@"opacity"];
    latido.fromValue = @0.25;
    latido.toValue = @0.85;
    latido.duration = 0.9;
    latido.autoreverses = YES;
    latido.repeatCount = HUGE_VALF;
    [self.spinner.layer addAnimation:latido forKey:@"latido"];

    self.loadingLabel = [[UILabel alloc] init];
    self.loadingLabel.font = tema.fontBody;
    self.loadingLabel.textColor = tema.textSecondary;
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    self.loadingLabel.numberOfLines = 4;
    self.loadingLabel.text = @"Abriendo documento...";
    [self.view addSubview:self.loadingLabel];
}

- (void)hideLoading {
    self.spinner.hidden = YES;
    self.loadingLabel.hidden = YES;
}

- (void)failWith:(NSString *)mensaje {
    [self hideLoading];
    self.loadingLabel.hidden = NO;
    self.loadingLabel.text = mensaje;
    if (self.onFailure) self.onFailure();
}

- (void)refreshNavigation {
    if (self.isEPUB || self.isOffice) {
        self.topBar.hidden = NO;
        BOOL hayAnterior = (self.chapterIndex > 0);
        BOOL haySiguiente = (self.chapterIndex + 1 < (NSInteger)self.slides.count);
        self.prevButton.enabled = hayAnterior;
        self.prevButton.alpha = hayAnterior ? 1 : 0.28;
        self.nextButton.enabled = haySiguiente;
        self.nextButton.alpha = haySiguiente ? 1 : 0.28;

        NSDictionary *slide = nil;
        if (self.slides.count > 0 && self.chapterIndex < (NSInteger)self.slides.count) {
            slide = self.slides[(NSUInteger)self.chapterIndex];
        }
        NSString *titulo = slide[@"title"];
        self.chapterLabel.text = [NSString stringWithFormat:@"%@  ·  %ld / %ld",
                                  titulo.length ? titulo : @"Documento",
                                  (long)(self.chapterIndex + 1),
                                  (long)MAX(1, self.slides.count)];
    } else {
        self.topBar.hidden = YES;
    }
    [self.view setNeedsLayout];
}

- (void)prevTapped:(UIButton *)sender {
    if (self.chapterIndex <= 0) return;
    [self saveProgressNow];
    [self showSlideAt:self.chapterIndex - 1];
}

- (void)nextTapped:(UIButton *)sender {
    if (self.chapterIndex + 1 >= (NSInteger)self.slides.count) return;
    [self saveProgressNow];
    [self showSlideAt:self.chapterIndex + 1];
}

#pragma mark - Navegacion

- (void)showSlideAt:(NSInteger)indice {
    if (!self.slides.count) return;
    NSInteger total = (NSInteger)self.slides.count;
    self.chapterIndex = MAX(0, MIN(total - 1, indice));
    self.restoredForSlide = NO;
    [self refreshNavigation];

    NSDictionary *slide = self.slides[(NSUInteger)self.chapterIndex];
    NSString *ruta = slide[@"path"];
    if (!ruta.length) {
        [self failWith:@"El capitulo no tiene contenido."];
        return;
    }

    self.spinner.hidden = NO;
    self.loadingLabel.hidden = NO;
    self.loadingLabel.text = @"Abriendo documento...";

    [self.webView removeFromSuperview];
    self.webView = nil;

    UIWebView *web = [[UIWebView alloc] initWithFrame:self.container.bounds];
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    web.delegate = self;
    web.backgroundColor = [IRTheme shared].readingBackground;
    web.opaque = NO;
    web.dataDetectorTypes = UIDataDetectorTypeNone;
    web.allowsInlineMediaPlayback = YES;
    web.mediaPlaybackAllowsAirPlay = YES;
    web.scalesPageToFit = self.isOffice ? YES : ![IRSettings shared].originalLayout;

    [self.container addSubview:web];
    self.webView = web;

    NSURL *url = [NSURL fileURLWithPath:ruta isDirectory:NO];
    [web loadRequest:[NSURLRequest requestWithURL:url]];
}

#pragma mark - UIWebView

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
                                                 navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        return NO;
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (webView != self.webView) return;
    [self hideLoading];
    if (self.restoredForSlide) return;
    self.restoredForSlide = YES;

    IRProgress *p = self.document.progress;
    if (self.isEPUB) {
        NSString *ancla = p.anchor ?: @"";
        NSRange hash = [ancla rangeOfString:@"#IRCBP#"];
        if (ancla.length && hash.location != NSNotFound) {
            NSString *base = [ancla substringToIndex:hash.location];
            NSString *destino = self.slides[(NSUInteger)self.chapterIndex][@"bookPath"] ?: @"";
            if (base.length && destino.length &&
                ([base hasSuffix:destino] || [destino hasSuffix:base])) {
                double ratio = [[ancla substringFromIndex:NSMaxRange(hash)] doubleValue];
                if (isfinite(ratio) && ratio > 0.0001) {
                    [self scrollToRatio:ratio];
                }
            }
        }
    } else if (self.isOffice) {
        [self scrollToRatio:p.ratio];
    } else {
        [self scrollToRatio:p.ratio];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (!error) return;
    if ([error code] == NSURLErrorCancelled) return;
    if (webView != self.webView) return;
    [self failWith:error.localizedDescription ?: @"No se pudo mostrar el documento."];
}

#pragma mark - Desplazamiento

- (double)currentScrollRatio {
    if (!self.webView) return 0;
    NSString *js =
        @"(function(){"
         "var y=window.scrollY||window.pageYOffset||document.documentElement.scrollTop||0;"
         "var h=Math.max(1,document.documentElement.scrollHeight||1);"
         "var v=window.innerHeight||document.documentElement.clientHeight||1;"
         "var m=h-v;"
         "if(m<=1){return 1;}"
         "return Math.min(1,Math.max(0,y/m));"
         "})()";
    double r = [[self.webView stringByEvaluatingJavaScriptFromString:js] doubleValue];
    if (!isfinite(r)) r = 0;
    return r;
}

- (void)scrollToRatio:(double)ratio {
    if (!self.webView) return;
    double r = MAX(0, MIN(1, ratio));
    NSString *js = [NSString stringWithFormat:
        @"(function(){"
         "var h=Math.max(1, document.documentElement.scrollHeight||1);"
         "var v=window.innerHeight||document.documentElement.clientHeight||1;"
         "window.scrollTo(0, (h-v)*%.6f);"
         "})();", r];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (NSString *)jsString:(NSString *)texto {
    return [NSString stringWithFormat:@"\"%@\"", [IRUtils jsonEscaped:texto ?: @""]];
}

#pragma mark - IRReader

- (void)saveProgressNow {
    if (!self.document) return;
    IRProgress *p = self.document.progress;

    if (self.isMedia) {
        p.seconds = CMTimeGetSeconds(self.player.currentTime);
        CGFloat fin = CMTimeGetSeconds(self.player.currentItem.duration);
        if (fin > 0 && isfinite(fin)) {
            p.ratio = MAX(0, MIN(1, p.seconds / fin));
            p.finished = (p.ratio > 0.985);
        }
        [[IRLibrary shared] save];
        return;
    }

    if (self.isEPUB) {
        p.page = self.chapterIndex + 1;
        p.pageCount = (NSInteger)MAX(1, self.slides.count);
        p.index = self.chapterIndex;
        p.ratio = ((double)(self.chapterIndex + 1)) / ((double)MAX(1, self.slides.count));
        p.finished = (self.chapterIndex + 1 >= (NSInteger)self.slides.count);
        NSDictionary *slide = nil;
        if (self.slides.count > 0 && self.chapterIndex < (NSInteger)self.slides.count) {
            slide = self.slides[(NSUInteger)self.chapterIndex];
        }
        NSString *destino = slide[@"bookPath"] ?: slide[@"relative"] ?: @"";
        p.anchor = [NSString stringWithFormat:@"%@#IRCBP#%.6f",
                    destino, [self currentScrollRatio]];
    } else if (self.isOffice) {
        p.page = self.chapterIndex + 1;
        p.pageCount = (NSInteger)MAX(1, self.slides.count);
        p.index = self.chapterIndex;
        p.ratio = [self currentScrollRatio];
        p.finished = (self.chapterIndex + 1 >= (NSInteger)self.slides.count && p.ratio > 0.985);
    } else {
        p.page = 1;
        p.pageCount = 1;
        p.ratio = [self currentScrollRatio];
        p.finished = (p.ratio > 0.985);
    }
    [[IRLibrary shared] save];
}

- (NSString *)pageLabel {
    if (self.isMedia) {
        double ahora = CMTimeGetSeconds(self.player.currentTime);
        double total = CMTimeGetSeconds(self.player.currentItem.duration);
        if (!isfinite(ahora) || ahora < 0) ahora = 0;
        if (!isfinite(total) || total <= 0) total = 0;
        return [NSString stringWithFormat:@"%@ / %@",
                [IRUtils formatDuration:ahora], [IRUtils formatDuration:total]];
    }
    if (self.isEPUB) {
        return [NSString stringWithFormat:@"Cap. %ld de %ld",
                (long)(self.chapterIndex + 1), (long)MAX(1, self.slides.count)];
    }
    if (self.isOffice) {
        return [NSString stringWithFormat:@"%ld de %ld",
                (long)(self.chapterIndex + 1), (long)MAX(1, self.slides.count)];
    }
    return [NSString stringWithFormat:@"%d%%", (int)round([self currentScrollRatio] * 100)];
}

- (NSInteger)pageCount {
    if (self.isEPUB || self.isOffice) return (NSInteger)MAX(1, self.slides.count);
    return 1;
}

- (NSInteger)currentPage {
    if (self.isEPUB || self.isOffice) return self.chapterIndex + 1;
    return 1;
}

- (void)goToPage:(NSInteger)page {
    if (self.isMedia) {
        double total = CMTimeGetSeconds(self.player.currentItem.duration);
        if (total > 0 && isfinite(total)) {
            double destino = MAX(0, MIN(total, total * ((double)MAX(1, page) / 100.0)));
            [self.player seekToTime:CMTimeMakeWithSeconds(destino, 600)];
        }
        return;
    }
    if (!self.isEPUB && !self.isOffice) {
        [self scrollToRatio:((double)MAX(1, page)) / ((double)MAX(1, [self pageCount]))];
        return;
    }
    [self showSlideAt:page - 1];
}

- (NSArray<IRTOCItem *> *)tableOfContents {
    NSMutableArray *salida = [NSMutableArray array];
    NSInteger i = 0;
    for (NSDictionary *slide in self.slides) {
        NSString *titulo = slide[@"title"];
        [salida addObject:[IRTOCItem itemWithTitle:titulo.length ? titulo : @"Documento"
                                             page:i + 1
                                            index:i
                                           anchor:slide[@"bookPath"] ?: @""
                                            level:0]];
        i++;
    }
    return salida;
}

- (void)jumpToTOCItem:(IRTOCItem *)item {
    if (!item) return;
    [self goToPage:item.page];
}

- (BOOL)supportsBookmarks { return YES; }

- (void)addBookmarkWithNote:(NSString *)note {
    IRBookmark *b = [IRBookmark bookmarkWithPage:[self currentPage]
                                           index:self.chapterIndex
                                          anchor:self.document.progress.anchor ?: @""
                                           label:[self pageLabel]
                                            note:note ?: @""];
    [self.document.bookmarks addObject:b];
    [[IRLibrary shared] save];
    [IRToast showIn:self.view message:@"Marcador guardado"];
}

- (BOOL)supportsSearch { return !self.isMedia; }

- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *))completion {
    if (!completion) return;
    NSString *q = [query stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (q.length < 2 || !self.webView) {
        completion(@[]);
        return;
    }

    NSString *js = [NSString stringWithFormat:
        @"(function(term){"
         "var out=[];"
         "var walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false);"
         "var n;var lower=term.toLowerCase();"
         "while(n=walker.nextNode()){"
         "var s=n.nodeValue||'';"
         "var i=s.toLowerCase().indexOf(lower);"
         "var hits=0;"
         "while(i>=0&&hits<3&&out.length<200){"
         "var p=n.parentNode;"
         "var block=(p&&p.closest)?p.closest('p,div,li,h1,h2,h3,h4,h5,h6,td,blockquote'):null;"
         "out.push({q:s.substr(i,term.length),"
         "t:(block?block.innerText:s).slice(0,140).replace(/\\s+/g,' ')});"
         "i=s.toLowerCase().indexOf(lower,i+term.length);hits++;"
         "}"
         "}"
         "return JSON.stringify(out);"
         "})(%@)", [self jsString:q]];

    NSString *resultado = [self.webView stringByEvaluatingJavaScriptFromString:js];
    NSData *datos = [resultado dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *lista = nil;
    if (datos.length) {
        id obj = [NSJSONSerialization JSONObjectWithData:datos options:0 error:NULL];
        if ([obj isKindOfClass:[NSArray class]]) lista = obj;
    }

    NSMutableArray *salida = [NSMutableArray array];
    for (id elemento in lista) {
        if (![elemento isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = elemento;
        NSString *snippet = d[@"t"];
        NSString *cita = d[@"q"];
        if (snippet.length) {
            IRSearchResult *r = [[IRSearchResult alloc] init];
            r.page = [self currentPage];
            r.index = (NSInteger)salida.count;
            r.quote = cita.length ? cita : q;
            r.snippet = snippet;
            [salida addObject:r];
        }
    }
    completion(salida);
}

- (void)jumpToSearchResult:(IRSearchResult *)result {
    if (!result || !self.webView) return;
    NSString *q = result.quote ?: @"";
    if (!q.length) return;
    NSString *js = [NSString stringWithFormat:
        @"(function(term){"
         "var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false),n;"
         "var lower=term.toLowerCase();"
         "while(n=w.nextNode()){"
         "var s=n.nodeValue||'';"
         "if(s.toLowerCase().indexOf(lower)>=0){"
         "var r=document.createRange();r.selectNodeContents(n);"
         "var b=r.getBoundingClientRect();"
         "window.scrollTo(0,(window.scrollY||0)+b.top-60);return '1';"
         "}}"
         "return '0';"
         "})(%@)", [self jsString:q]];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)applyDisplaySettings {
    IRTheme *tema = [IRTheme shared];
    self.view.backgroundColor = tema.readingBackground;
    self.container.backgroundColor = tema.readingBackground;
    self.topBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.97];
    self.chapterLabel.textColor = tema.textPrimary;
    self.webView.backgroundColor = tema.readingBackground;
    self.webView.opaque = NO;
    self.loadingLabel.textColor = tema.textSecondary;
    self.mediaBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.96];
    self.timeLabel.textColor = tema.textSecondary;
    [self.view setNeedsLayout];
}

- (BOOL)isPaginated { return NO; }

#pragma mark - Carga

- (void)startLoading {
    NSString *ext = [[self.document.path pathExtension] lowercaseString];
    NSArray *ofimaticos = @[@"docx", @"xlsx", @"pptx", @"odt", @"ods", @"odp"];
    NSArray *antiguos = @[@"doc", @"xls", @"ppt"];
    NSArray *multimedia = @[@"mp3", @"m4a", @"aac", @"wav", @"aif", @"aiff",
                            @"mp4", @"mov", @"m4v", @"mpg", @"mpeg"];

    if ([ext isEqualToString:@"epub"]) {
        [IRUtils runInBackground:^{ [self openEPUB]; }];
    } else if ([antiguos containsObject:ext]) {
        [self failWith:@"Los documentos de Office 97 usan un formato propietario "
                        "que no se puede reconstruir con fidelidad. Exportalos a PDF "
                        "y vuelvelos a importar."];
    } else if ([ofimaticos containsObject:ext]) {
        [IRUtils runInBackground:^{ [self openOffice:ext]; }];
    } else if ([multimedia containsObject:ext]) {
        [self openMedia];
    } else if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"] ||
               [ext isEqualToString:@"xhtml"] || [ext isEqualToString:@"svg"]) {
        [self openHTML];
    } else {
        [self failWith:@"Este tipo de documento no se puede mostrar."];
    }
}

- (void)openHTML {
    [self hideLoading];
    self.isOffice = NO;
    self.isEPUB = NO;
    self.chapterIndex = 0;
    self.slides = [NSMutableArray arrayWithObject:@{
        @"path": self.document.path,
        @"title": self.document.title.length ? self.document.title : @"Documento"
    }];
    [self refreshNavigation];
    [self showSlideAt:0];
}

#pragma mark - EPUB

- (void)openEPUB {
    NSError *error = nil;
    IREPUBDocument *libro = [IREPUBDocument documentAtPath:self.document.path error:&error];
    if (!libro || libro.chapterCount == 0) {
        NSString *motivo = error.localizedDescription ?: @"No se pudo abrir el EPUB.";
        [IRUtils runOnMain:^{ [self failWith:motivo]; }];
        return;
    }

    NSMutableArray *vistas = [NSMutableArray array];
    for (NSInteger i = 0; i < libro.chapterCount; i++) {
        NSDictionary *item = [libro spineItemAtIndex:i];
        if (!item) continue;
        NSString *ruta = item[@"fullPath"];
        if (!ruta.length) continue;
        NSString *titulo = [libro chapterTitleAtIndex:i];
        [vistas addObject:@{
            @"path": ruta,
            @"bookPath": item[@"href"] ?: @"",
            @"relative": item[@"href"] ?: @"",
            @"title": titulo.length ? titulo : @"Capitulo"
        }];
    }

    if (!vistas.count) {
        [IRUtils runOnMain:^{ [self failWith:@"El EPUB no contiene capitulos legibles."]; }];
        return;
    }

    [IRUtils runOnMain:^{
        self.slides = vistas;
        self.isEPUB = YES;
        self.isOffice = NO;
        [self hideLoading];
        [self refreshNavigation];
        IRProgress *p = self.document.progress;
        NSInteger objetivo = MAX(0, p.page - 1);
        NSString *ancla = p.anchor ?: @"";
        NSRange hash = [ancla rangeOfString:@"#IRCBP#"];
        NSString *base = (hash.location != NSNotFound)
            ? [ancla substringToIndex:hash.location] : ancla;
        if (base.length) {
            for (NSUInteger i = 0; i < vistas.count; i++) {
                NSString *bookPath = vistas[i][@"bookPath"];
                if (bookPath.length && [base hasSuffix:bookPath]) {
                    objetivo = (NSInteger)i;
                    break;
                }
            }
        }
        [self showSlideAt:MIN((NSInteger)vistas.count - 1, objetivo)];
    }];
}

#pragma mark - Multimedia

- (void)openMedia {
    [self hideLoading];
    self.isMedia = YES;
    self.isEPUB = NO;
    self.isOffice = NO;
    [self refreshNavigation];

    NSURL *url = [NSURL fileURLWithPath:self.document.path isDirectory:NO];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.container.bounds;
    [self.container.layer addSublayer:self.playerLayer];

    [self buildMediaBar];
    [self.view setNeedsLayout];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaFinished:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];

    double segundo = self.document.progress.seconds;
    if (segundo > 0 && isfinite(segundo)) {
        [self.player seekToTime:CMTimeMakeWithSeconds(segundo, 600)];
    }

    [self updateMediaBar];
    self.mediaTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                       target:self
                                                     selector:@selector(updateMediaBar)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)buildMediaBar {
    IRTheme *tema = [IRTheme shared];
    self.mediaBar = [[UIView alloc] init];
    self.mediaBar.backgroundColor = [tema.cardBackground colorWithAlphaComponent:0.96];
    [self.container addSubview:self.mediaBar];

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton setImage:[IRIcons icon:IRGlyphPlay size:22 color:tema.textPrimary]
                     forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(togglePlayback)
              forControlEvents:UIControlEventTouchUpInside];
    [self.mediaBar addSubview:self.playButton];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [tema fontMono:12];
    self.timeLabel.textColor = tema.textSecondary;
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.text = @"0:00 / 0:00";
    [self.mediaBar addSubview:self.timeLabel];

    self.timeSlider = [[UISlider alloc] init];
    self.timeSlider.minimumValue = 0;
    self.timeSlider.maximumValue = 1;
    self.timeSlider.value = 0;
    self.timeSlider.minimumTrackTintColor = tema.accent;
    [self.timeSlider addTarget:self action:@selector(sliderChanged:)
              forControlEvents:UIControlEventValueChanged];
    [self.timeSlider addTarget:self action:@selector(sliderReleased:)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.mediaBar addSubview:self.timeSlider];
}

- (void)togglePlayback {
    if (!self.player) return;
    if (self.player.rate > 0.01) {
        [self.player pause];
    } else {
        [self.player play];
    }
    [self updateMediaBar];
}

- (void)sliderChanged:(UISlider *)slider {
    self.updatingSlider = YES;
    double total = CMTimeGetSeconds(self.player.currentItem.duration);
    if (total > 0 && isfinite(total)) {
        double destino = total * (double)slider.value;
        [self.player seekToTime:CMTimeMakeWithSeconds(destino, 600)];
        self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                               [IRUtils formatDuration:destino],
                               [IRUtils formatDuration:total]];
    }
}

- (void)sliderReleased:(UISlider *)slider {
    self.updatingSlider = NO;
}

- (void)updateMediaBar {
    if (!self.player) return;
    double ahora = CMTimeGetSeconds(self.player.currentTime);
    double total = CMTimeGetSeconds(self.player.currentItem.duration);
    if (!isfinite(ahora) || ahora < 0) ahora = 0;
    if (!isfinite(total) || total <= 0) total = 0;

    if (!self.updatingSlider && total > 0) {
        self.timeSlider.value = (float)MAX(0, MIN(1, ahora / total));
    }
    self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                           [IRUtils formatDuration:ahora],
                           [IRUtils formatDuration:total]];

    BOOL reproduciendo = self.player.rate > 0.01;
    UIImage *icono = [IRIcons icon:(reproduciendo ? IRGlyphPause : IRGlyphPlay)
                              size:22
                             color:[IRTheme shared].textPrimary];
    [self.playButton setImage:icono forState:UIControlStateNormal];
}

- (void)mediaFinished:(NSNotification *)nota {
    [self.player pause];
    [self updateMediaBar];
}

#pragma mark - Office

- (void)openOffice:(NSString *)ext {
    NSString *cache = [[IRUtils cachesPath] stringByAppendingPathComponent:
                       [IRUtils sha1OfString:[NSString stringWithFormat:@"office|%@",
                                              self.document.path]]];
    NSString *marca = [cache stringByAppendingPathComponent:@".completo"];
    NSString *contenido = [cache stringByAppendingPathComponent:@".contenido"];
    NSFileManager *gestor = [NSFileManager defaultManager];
    NSMutableArray *vistas = [NSMutableArray array];
    NSString *fallo = nil;

    @try {
        if (![gestor fileExistsAtPath:marca]) {
            [gestor removeItemAtPath:cache error:NULL];
            [gestor createDirectoryAtPath:cache withIntermediateDirectories:YES
                               attributes:nil error:NULL];
            if (![IRArchive extractArchive:self.document.path
                               toDirectory:contenido
                                  progress:nil
                                    cancel:nil
                                     error:NULL]) {
                @throw [NSException exceptionWithName:@"IRExtraccion"
                                               reason:@"No se pudo descomprimir el documento."
                                             userInfo:nil];
            }
            [@"1" writeToFile:marca atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
        }
        vistas = [self viewsForOffice:ext inDirectory:contenido cache:cache];
    } @catch (NSException *excepcion) {
        fallo = excepcion.reason ?: @"No se pudo abrir el documento.";
    }

    NSString *motivo = fallo;
    [IRUtils runOnMain:^{
        if (!vistas.count) {
            [self failWith:motivo ?: @"El documento no tiene contenido visible."];
            return;
        }
        self.slides = vistas;
        self.isOffice = YES;
        self.isEPUB = NO;
        [self hideLoading];
        [self refreshNavigation];
        IRProgress *p = self.document.progress;
        NSInteger objetivo = MAX(0, MIN((NSInteger)vistas.count - 1, p.page - 1));
        [self showSlideAt:objetivo];
    }];
}

- (NSMutableArray<NSDictionary *> *)viewsForOffice:(NSString *)ext
                                      inDirectory:(NSString *)cache
                                            cache:(NSString *)root {
    NSMutableArray *vistas = [NSMutableArray array];
    NSFileManager *gestor = [NSFileManager defaultManager];
    NSString *htmlDir = [root stringByAppendingPathComponent:@".html"];
    [gestor createDirectoryAtPath:htmlDir withIntermediateDirectories:YES
                       attributes:nil error:NULL];

    if ([ext isEqualToString:@"docx"]) {
        NSString *doc = [cache stringByAppendingPathComponent:@"word/document.xml"];
        NSString *html = [IRWebReaderViewController docxHTMLAtPath:doc];
        NSString *destino = [htmlDir stringByAppendingPathComponent:@"documento.html"];
        if (html.length) {
            [html writeToFile:destino atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
            [vistas addObject:@{@"path": destino, @"title": @"Documento"}];
        }
        return vistas;
    }

    if ([ext isEqualToString:@"xlsx"]) {
        NSString *compartidas = [cache stringByAppendingPathComponent:@"xl/sharedStrings.xml"];
        NSArray *textos = [IRWebReaderViewController sharedStringsAtPath:compartidas];
        NSString *carpeta = [cache stringByAppendingPathComponent:@"xl/worksheets"];
        NSArray *hojas = [gestor contentsOfDirectoryAtPath:carpeta error:NULL];
        NSMutableArray *ordenadas = [NSMutableArray array];
        for (NSString *hoja in hojas) {
            if ([[[hoja pathExtension] lowercaseString] isEqualToString:@"xml"]) {
                [ordenadas addObject:hoja];
            }
        }
        [ordenadas sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [IRUtils naturalCompare:a with:b];
        }];
        for (NSString *hoja in ordenadas) {
            NSString *origen = [carpeta stringByAppendingPathComponent:hoja];
            NSString *html = [IRWebReaderViewController xlsxHTMLAtPath:origen shared:textos];
            if (!html.length) continue;
            NSString *nombre = [[hoja stringByDeletingPathExtension]
                                stringByAppendingString:@".html"];
            NSString *destino = [htmlDir stringByAppendingPathComponent:nombre];
            [html writeToFile:destino atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
            [vistas addObject:@{@"path": destino,
                                @"title": [hoja stringByDeletingPathExtension]}];
        }
        return vistas;
    }

    if ([ext isEqualToString:@"pptx"]) {
        CGSize tamano = [IRWebReaderViewController pptxSlideSizeAtPath:
                         [cache stringByAppendingPathComponent:@"ppt/presentation.xml"]];
        NSString *carpeta = [cache stringByAppendingPathComponent:@"ppt/slides"];
        NSArray *diapositivas = [gestor contentsOfDirectoryAtPath:carpeta error:NULL];
        NSMutableArray *ordenadas = [NSMutableArray array];
        for (NSString *slide in diapositivas) {
            if ([[[slide pathExtension] lowercaseString] isEqualToString:@"xml"]) {
                [ordenadas addObject:slide];
            }
        }
        [ordenadas sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [IRUtils naturalCompare:a with:b];
        }];
        NSInteger numero = 0;
        for (NSString *slide in ordenadas) {
            numero++;
            NSString *origen = [carpeta stringByAppendingPathComponent:slide];
            NSString *html = [IRWebReaderViewController pptxHTMLAtPath:origen size:tamano];
            if (!html.length) continue;
            NSString *nombre = [NSString stringWithFormat:@"diapositiva%03ld.html", (long)numero];
            NSString *destino = [htmlDir stringByAppendingPathComponent:nombre];
            [html writeToFile:destino atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
            [vistas addObject:@{@"path": destino,
                                @"title": [NSString stringWithFormat:@"Diapositiva %ld",
                                           (long)numero]}];
        }
        return vistas;
    }

    // ODT, ODS y ODP: se extrae el texto de content.xml conservando parrafos.
    NSString *content = [cache stringByAppendingPathComponent:@"content.xml"];
    NSString *html = [IRWebReaderViewController openDocumentHTMLAtPath:content];
    NSString *destino = [htmlDir stringByAppendingPathComponent:@"documento.html"];
    if (html.length) {
        [html writeToFile:destino atomically:YES
                 encoding:NSUTF8StringEncoding error:NULL];
        [vistas addObject:@{@"path": destino, @"title": @"Documento"}];
    }
    return vistas;
}

#pragma mark - Conversion de Office

+ (NSString *)escapeHTML:(NSString *)texto {
    NSMutableString *s = [NSMutableString stringWithString:texto ?: @""];
    [s replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@">" withString:@"&gt;" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0
                            range:NSMakeRange(0, s.length)];
    return s;
}

+ (NSString *)decodeEntities:(NSString *)texto {
    if (!texto.length) return @"";
    NSMutableString *s = [NSMutableString stringWithString:texto];
    [s replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&gt;" withString:@">" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0
                            range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0
                            range:NSMakeRange(0, s.length)];

    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
                               @"&#(x?)([0-9A-Fa-f]+);" options:0 error:NULL];
    NSArray *coincidencias = [re matchesInString:s options:0
                                           range:NSMakeRange(0, s.length)];
    for (NSTextCheckingResult *m in [coincidencias reverseObjectEnumerator]) {
        NSString *prefijo = [s substringWithRange:[m rangeAtIndex:1]];
        NSString *digitos = [s substringWithRange:[m rangeAtIndex:2]];
        long long valor = 0;
        NSScanner *escanner = [NSScanner scannerWithString:digitos];
        if (prefijo.length) {
            unsigned int hexadecimal = 0;
            [escanner scanHexInt:&hexadecimal];
            valor = hexadecimal;
        } else {
            [escanner scanLongLong:&valor];
        }
        if (valor > 0 && valor < 0x110000) {
            NSString *caracter = [NSString stringWithFormat:@"%C", (unichar)valor];
            [s replaceCharactersInRange:m.range withString:caracter];
        }
    }
    return s;
}

+ (NSArray<NSTextCheckingResult *> *)matches:(NSString *)patron in:(NSString *)texto {
    if (!texto.length) return @[];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patron
                                        options:NSRegularExpressionDotMatchesLineSeparators |
                                                NSRegularExpressionCaseInsensitive
                                          error:NULL];
    if (!re) return @[];
    return [re matchesInString:texto options:0 range:NSMakeRange(0, texto.length)];
}

+ (NSString *)firstMatch:(NSString *)patron in:(NSString *)texto group:(NSInteger)grupo {
    if (!texto.length) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patron
                                        options:NSRegularExpressionDotMatchesLineSeparators |
                                                NSRegularExpressionCaseInsensitive
                                          error:NULL];
    if (!re) return nil;
    NSTextCheckingResult *m = [re firstMatchInString:texto options:0
                                               range:NSMakeRange(0, texto.length)];
    if (!m || grupo < 0 || grupo >= (NSInteger)m.numberOfRanges) return nil;
    NSRange r = [m rangeAtIndex:(NSUInteger)grupo];
    if (r.location == NSNotFound) return nil;
    return [texto substringWithRange:r];
}

+ (NSString *)textFromMatches:(NSString *)patron in:(NSString *)texto group:(NSInteger)grupo {
    NSMutableString *salida = [NSMutableString string];
    for (NSTextCheckingResult *m in [self matches:patron in:texto]) {
        if (grupo < 0 || grupo >= (NSInteger)m.numberOfRanges) continue;
        NSRange r = [m rangeAtIndex:(NSUInteger)grupo];
        if (r.location == NSNotFound) continue;
        [salida appendString:[texto substringWithRange:r]];
    }
    return salida;
}

+ (NSString *)stripTags:(NSString *)xml {
    NSString *sin = [xml stringByReplacingOccurrencesOfString:@"<[^>]+>"
                                                   withString:@" "
                                                      options:NSRegularExpressionSearch
                                                        range:NSMakeRange(0, xml.length)];
    return [self decodeEntities:sin];
}

+ (NSString *)htmlDocument:(NSString *)cuerpo css:(NSString *)css ancho:(NSInteger)ancho {
    return [NSString stringWithFormat:
        @"<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
         "<meta name=\"viewport\" content=\"width=%ld, initial-scale=1.0\">"
         "<style>%@</style></head><body>%@</body></html>",
        (long)MAX(240, ancho), css ?: @"", cuerpo ?: @""];
}

+ (NSArray<NSString *> *)sharedStringsAtPath:(NSString *)ruta {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    if (!xml.length) return @[];
    NSMutableArray *salida = [NSMutableArray array];
    for (NSTextCheckingResult *m in [self matches:@"<si[^>]*>(.*?)</si>" in:xml]) {
        NSString *bloque = [xml substringWithRange:[m rangeAtIndex:1]];
        NSString *texto = [self textFromMatches:@"<t[^>]*>(.*?)</t>" in:bloque group:1];
        [salida addObject:[self decodeEntities:texto]];
    }
    return salida;
}

+ (NSInteger)columnIndexForReference:(NSString *)letras {
    NSInteger total = 0;
    NSString *mayus = [letras uppercaseString];
    for (NSUInteger i = 0; i < mayus.length; i++) {
        unichar c = [mayus characterAtIndex:i];
        if (c < 'A' || c > 'Z') continue;
        total = total * 26 + (NSInteger)(c - 'A' + 1);
    }
    return MAX(0, total - 1);
}

+ (NSString *)docxHTMLAtPath:(NSString *)ruta {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    if (!xml.length) return nil;

    NSString *carpeta = [ruta stringByDeletingLastPathComponent];
    NSString *estilos = [NSString stringWithContentsOfFile:
                         [carpeta stringByAppendingPathComponent:@"styles.xml"]
                                                 encoding:NSUTF8StringEncoding error:NULL];

    NSString *fuente = [self firstMatch:@"<w:rFonts[^>]*w:ascii=\"([^\"]+)\""
                                    in:estilos group:1];
    if (!fuente.length) fuente = @"Times New Roman";
    NSString *tamBase = [self firstMatch:@"<w:sz w:val=\"(\\d+)\"" in:estilos group:1];
    double basePt = tamBase.length ? tamBase.doubleValue / 2.0 : 11.0;

    NSString *anchoTw = [self firstMatch:@"<w:pgSz[^>]*w:w=\"(\\d+)\"" in:xml group:1];
    NSString *altoTw = [self firstMatch:@"<w:pgSz[^>]*w:h=\"(\\d+)\"" in:xml group:1];
    NSString *izq = [self firstMatch:@"<w:pgMar[^>]*w:left=\"(\\d+)\"" in:xml group:1];
    NSString *der = [self firstMatch:@"<w:pgMar[^>]*w:right=\"(\\d+)\"" in:xml group:1];
    NSString *sup = [self firstMatch:@"<w:pgMar[^>]*w:top=\"(\\d+)\"" in:xml group:1];
    NSString *inf = [self firstMatch:@"<w:pgMar[^>]*w:bottom=\"(\\d+)\"" in:xml group:1];

    NSInteger anchoPx = MAX(320, (anchoTw.length ? anchoTw.integerValue : 11906) / 15);
    NSInteger altoPx = MAX(320, (altoTw.length ? altoTw.integerValue : 16838) / 15);
    NSInteger izqPx = (izq.length ? izq.integerValue : 1134) / 15;
    NSInteger derPx = (der.length ? der.integerValue : 1134) / 15;
    NSInteger supPx = (sup.length ? sup.integerValue : 1134) / 15;
    NSInteger infPx = (inf.length ? inf.integerValue : 1134) / 15;

    NSMutableString *cuerpo = [NSMutableString string];
    NSUInteger pos = 0;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
                               @"<w:(p|tbl)(?:\\s[^>]*)?>"
                                        options:NSRegularExpressionCaseInsensitive
                                          error:NULL];
    while (pos < xml.length) {
        NSTextCheckingResult *m = [re firstMatchInString:xml options:0
                                                   range:NSMakeRange(pos, xml.length - pos)];
        if (!m) break;
        NSString *etiqueta = [xml substringWithRange:[m rangeAtIndex:1]];
        NSUInteger inicio = NSMaxRange(m.range);
        NSString *cierre = [etiqueta isEqualToString:@"p"] ? @"</w:p>" : @"</w:tbl>";
        NSRange primero = [xml rangeOfString:cierre options:0
                                       range:NSMakeRange(inicio, xml.length - inicio)];
        if (primero.location == NSNotFound) break;
        NSString *bloque = [xml substringWithRange:
                            NSMakeRange(inicio, primero.location - inicio)];
        if ([etiqueta isEqualToString:@"p"]) {
            NSString *html = [self docxParagraphHTML:bloque basePt:basePt];
            if (html.length) [cuerpo appendString:html];
        } else {
            [cuerpo appendString:[self docxTableHTML:bloque]];
        }
        pos = NSMaxRange(primero);
    }

    if (!cuerpo.length) return nil;

    NSString *css = [NSString stringWithFormat:
        @"html,body{margin:0;padding:0;background:#fff;color:#111;}"
         @"body{font-family:'%@',serif;font-size:%.1fpt;width:%ldpx;"
         @"min-height:%ldpx;padding:%ldpx %ldpx %ldpx %ldpx;box-sizing:border-box;"
         @"line-height:1.38;-webkit-text-size-adjust:none;}"
         @"p{margin:0 0 0.55em 0;}"
         @"h1,h2,h3,h4,h5,h6{margin:0.7em 0 0.4em 0;line-height:1.2;}"
         @"table{border-collapse:collapse;width:100%%;margin:0.4em 0;}"
         @"td,th{border:1px solid #999;padding:3px 5px;vertical-align:top;"
         @"font-size:%.1fpt;}"
         @"img{max-width:100%%;height:auto;}",
        fuente, basePt, (long)anchoPx, (long)altoPx,
        (long)supPx, (long)derPx, (long)infPx, (long)izqPx, basePt];

    return [self htmlDocument:cuerpo css:css ancho:anchoPx];
}

+ (NSString *)docxParagraphHTML:(NSString *)bloque basePt:(double)basePt {
    NSString *jc = [self firstMatch:@"<w:jc w:val=\"([^\"]+)\"" in:bloque group:1];
    NSString *pStyle = [self firstMatch:@"<w:pStyle w:val=\"([^\"]+)\"" in:bloque group:1];
    NSInteger nivel = 0;
    NSString *estiloMin = [pStyle lowercaseString];
    if (pStyle.length &&
        ([estiloMin rangeOfString:@"heading"].location != NSNotFound ||
         [estiloMin rangeOfString:@"titulo"].location != NSNotFound)) {
        NSString *ultimo = [pStyle substringFromIndex:MAX(0, (NSInteger)pStyle.length - 1)];
        nivel = MAX(1, MIN(6, ultimo.integerValue));
    }

    NSMutableString *runs = [NSMutableString string];
    for (NSTextCheckingResult *m in [self matches:@"<w:r(?:\\s[^>]*)?>(.*?)</w:r>"
                                            in:bloque]) {
        NSString *run = [bloque substringWithRange:[m rangeAtIndex:1]];
        NSString *rPr = [self firstMatch:@"<w:rPr>(.*?)</w:rPr>" in:run group:1] ?: @"";

        BOOL negrita = ([rPr rangeOfString:@"<w:b/>"].location != NSNotFound ||
                        [rPr rangeOfString:@"<w:b "].location != NSNotFound);
        BOOL cursiva = ([rPr rangeOfString:@"<w:i/>"].location != NSNotFound ||
                        [rPr rangeOfString:@"<w:i "].location != NSNotFound);
        BOOL subrayado = ([rPr rangeOfString:@"<w:u "].location != NSNotFound);
        NSString *szRun = [self firstMatch:@"<w:sz w:val=\"(\\d+)\"" in:rPr group:1];
        double pt = szRun.length ? szRun.doubleValue / 2.0 : basePt;
        NSString *color = [self firstMatch:@"<w:color w:val=\"([0-9A-Fa-f]{6})\""
                                        in:rPr group:1];

        NSString *texto = [self textFromMatches:@"<w:t(?:\\s[^>]*)?>(.*?)</w:t>" in:run group:1];
        if (!texto.length) {
            if ([run rangeOfString:@"<w:br"].location != NSNotFound) {
                [runs appendString:@"<br>"];
            }
            continue;
        }

        NSMutableString *estilo = [NSMutableString string];
        [estilo appendFormat:@"font-size:%.1fpt;", pt];
        if (negrita) [estilo appendString:@"font-weight:bold;"];
        if (cursiva) [estilo appendString:@"font-style:italic;"];
        if (subrayado) [estilo appendString:@"text-decoration:underline;"];
        if (color.length) [estilo appendFormat:@"color:#%@;", color];

        [runs appendFormat:@"<span style=\"%@\">%@</span>",
         estilo, [self escapeHTML:[self decodeEntities:texto]]];
    }

    if (!runs.length) return @"";

    NSString *alineacion = @"";
    if ([jc isEqualToString:@"center"]) alineacion = @"text-align:center;";
    else if ([jc isEqualToString:@"right"] || [jc isEqualToString:@"end"]) {
        alineacion = @"text-align:right;";
    } else if ([jc isEqualToString:@"both"]) alineacion = @"text-align:justify;";

    NSString *etiqueta = nivel > 0
        ? [NSString stringWithFormat:@"h%ld", (long)nivel] : @"p";
    return [NSString stringWithFormat:@"<%@ style=\"%@\">%@</%@>",
            etiqueta, alineacion, runs, etiqueta];
}

+ (NSString *)docxTableHTML:(NSString *)bloque {
    NSMutableString *html = [NSMutableString stringWithString:@"<table>"];
    for (NSTextCheckingResult *filaM in [self matches:@"<w:tr(?:\\s[^>]*)?>(.*?)</w:tr>" in:bloque]) {
        NSString *fila = [bloque substringWithRange:[filaM rangeAtIndex:1]];
        [html appendString:@"<tr>"];
        for (NSTextCheckingResult *celdaM in [self matches:@"<w:tc(?:\\s[^>]*)?>(.*?)</w:tc>"
                                                      in:fila]) {
            NSString *celda = [fila substringWithRange:[celdaM rangeAtIndex:1]];
            NSString *texto = [self textFromMatches:@"<w:t(?:\\s[^>]*)?>(.*?)</w:t>" in:celda group:1];
            NSString *negrita = ([celda rangeOfString:@"<w:b/>"].location != NSNotFound)
                ? @" style=\"font-weight:bold;\"" : @"";
            [html appendFormat:@"<td%@>%@</td>", negrita,
             [self escapeHTML:[self decodeEntities:texto]]];
        }
        [html appendString:@"</tr>"];
    }
    [html appendString:@"</table>"];
    return html;
}

+ (NSString *)xlsxHTMLAtPath:(NSString *)ruta shared:(NSArray<NSString *> *)compartidas {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    if (!xml.length) return nil;

    NSMutableString *cuerpo = [NSMutableString string];
    NSMutableString *columnas = [NSMutableString string];
    for (NSTextCheckingResult *m in [self matches:@"<col(?:\\s[^>]*)?/>" in:xml]) {
        NSString *col = [xml substringWithRange:m.range];
        NSString *ancho = [self firstMatch:@"width=\"([0-9.]+)\"" in:col group:1];
        if (ancho.length) {
            [columnas appendFormat:@"<col style=\"width:%.0fpx\">",
             MAX(30.0, ancho.doubleValue * 7.0)];
        }
    }
    if (columnas.length) {
        [cuerpo appendFormat:@"<colgroup>%@</colgroup>", columnas];
    }

    NSInteger filas = 0;
    for (NSTextCheckingResult *filaM in [self matches:@"<row(?:\\s[^>]*)?>(.*?)</row>" in:xml]) {
        if (filas >= 4000) break;
        filas++;
        NSString *fila = [xml substringWithRange:[filaM rangeAtIndex:1]];
        [cuerpo appendString:@"<tr>"];
        NSInteger columna = 0;
        for (NSTextCheckingResult *celdaM in [self matches:@"<c\\b[^>]*(?:/>|>.*?</c>)" in:fila]) {
            NSString *celda = [fila substringWithRange:celdaM.range];
            NSString *attrs = [self firstMatch:@"^<c([^>]*)" in:celda group:1] ?: @"";
            NSString *ref = [self firstMatch:@"r=\"([A-Z]+)[0-9]+\"" in:attrs group:1];
            NSInteger destino = ref.length ? [self columnIndexForReference:ref] : columna;
            while (columna < destino) {
                [cuerpo appendString:@"<td></td>"];
                columna++;
            }

            NSString *tipo = [self firstMatch:@"t=\"([^\"]+)\"" in:attrs group:1];
            NSString *valor = [self firstMatch:@">(?:<is>)?<t(?:\\s[^>]*)?>(.*?)</t>"
                                            in:celda group:1];
            if (!valor.length) valor = [self firstMatch:@"<v>(.*?)</v>" in:celda group:1];
            valor = [self decodeEntities:valor ?: @""];

            if ([tipo isEqualToString:@"s"]) {
                NSInteger indice = valor.integerValue;
                if (indice >= 0 && indice < (NSInteger)compartidas.count) {
                    valor = compartidas[(NSUInteger)indice];
                }
            } else if ([tipo isEqualToString:@"b"]) {
                valor = valor.integerValue ? @"VERDADERO" : @"FALSO";
            }

            BOOL numerico = (!tipo.length || [tipo isEqualToString:@"n"]);
            [cuerpo appendFormat:@"<td%@>%@</td>", numerico ? @" class=\"num\"" : @"",
             [self escapeHTML:valor]];
            columna++;
        }
        [cuerpo appendString:@"</tr>"];
    }

    if (filas == 0) return nil;

    NSString *css =
        @"html,body{margin:0;padding:0;background:#fff;color:#111;}"
         @"body{font-family:'Helvetica Neue',Arial,sans-serif;font-size:11pt;"
         @"-webkit-text-size-adjust:none;padding:10px;}"
         @"table{border-collapse:collapse;table-layout:auto;}"
         @"td{border:1px solid #d8d8d8;padding:3px 7px;vertical-align:top;"
         @"white-space:nowrap;}"
         @"td.num{text-align:right;}";

    return [self htmlDocument:cuerpo css:css ancho:900];
}

+ (CGSize)pptxSlideSizeAtPath:(NSString *)ruta {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    NSString *cx = [self firstMatch:@"<p:sldSz[^>]*cx=\"(\\d+)\"" in:xml group:1];
    NSString *cy = [self firstMatch:@"<p:sldSz[^>]*cy=\"(\\d+)\"" in:xml group:1];
    double ancho = cx.length ? cx.doubleValue / 9525.0 : 960.0;
    double alto = cy.length ? cy.doubleValue / 9525.0 : 720.0;
    return CGSizeMake(MAX(320.0, ancho), MAX(240.0, alto));
}

+ (NSString *)pptxHTMLAtPath:(NSString *)ruta size:(CGSize)tamano {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    if (!xml.length) return nil;

    NSMutableString *cuerpo = [NSMutableString string];
    for (NSTextCheckingResult *m in [self matches:@"<p:sp>.*?</p:sp>" in:xml]) {
        NSString *sp = [xml substringWithRange:m.range];
        NSString *xfrm = [self firstMatch:@"<a:xfrm[^>]*>(.*?)</a:xfrm>" in:sp group:1];
        if (!xfrm.length) continue;

        NSString *x = [self firstMatch:@"<a:off[^>]*x=\"(-?\\d+)\"" in:xfrm group:1];
        NSString *y = [self firstMatch:@"<a:off[^>]*y=\"(-?\\d+)\"" in:xfrm group:1];
        NSString *cx = [self firstMatch:@"<a:ext[^>]*cx=\"(\\d+)\"" in:xfrm group:1];
        NSString *cy = [self firstMatch:@"<a:ext[^>]*cy=\"(\\d+)\"" in:xfrm group:1];

        NSMutableString *texto = [NSMutableString string];
        for (NSTextCheckingResult *pm in [self matches:@"<a:p>.*?</a:p>" in:sp]) {
            NSString *parrafo = [sp substringWithRange:pm.range];
            NSString *algn = [self firstMatch:@"<a:pPr[^>]*algn=\"([a-z]+)\"" in:parrafo group:1];
            NSMutableString *linea = [NSMutableString string];

            for (NSTextCheckingResult *rm in [self matches:@"<a:r>.*?</a:r>" in:parrafo]) {
                NSString *run = [parrafo substringWithRange:rm.range];
                NSString *t = [self firstMatch:@"<a:t>(.*?)</a:t>" in:run group:1];
                if (!t.length) continue;

                NSString *rPr = [self firstMatch:@"<a:rPr[^>]*>" in:run group:0] ?: @"";
                NSString *sz = [self firstMatch:@"sz=\"(\\d+)\"" in:rPr group:1];
                double pt = sz.length ? sz.doubleValue / 100.0 : 18.0;
                BOOL negrita = ([rPr rangeOfString:@" b=\"1\""].location != NSNotFound ||
                                [rPr rangeOfString:@" b=\"true\""].location != NSNotFound);
                BOOL cursiva = ([rPr rangeOfString:@" i=\"1\""].location != NSNotFound ||
                                [rPr rangeOfString:@" i=\"true\""].location != NSNotFound);
                NSString *color = [self firstMatch:@"<a:srgbClr val=\"([0-9A-Fa-f]{6})\""
                                                in:run group:1];

                NSMutableString *estilo = [NSMutableString string];
                [estilo appendFormat:@"font-size:%.1fpt;", pt];
                if (negrita) [estilo appendString:@"font-weight:bold;"];
                if (cursiva) [estilo appendString:@"font-style:italic;"];
                if (color.length) [estilo appendFormat:@"color:#%@;", color];

                [linea appendFormat:@"<span style=\"%@\">%@</span>",
                 estilo, [self escapeHTML:[self decodeEntities:t]]];
            }

            if (!linea.length) continue;
            NSString *alineacion = @"";
            if ([algn isEqualToString:@"ctr"]) alineacion = @"text-align:center;";
            else if ([algn isEqualToString:@"r"]) alineacion = @"text-align:right;";
            else if ([algn isEqualToString:@"just"]) alineacion = @"text-align:justify;";
            [texto appendFormat:@"<p style=\"%@\">%@</p>", alineacion, linea];
        }

        if (!texto.length) continue;
        [cuerpo appendFormat:
            @"<div class=\"caja\" style=\"left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;\">"
             @"%@</div>",
            x.doubleValue / 9525.0, y.doubleValue / 9525.0,
            MAX(12.0, cx.doubleValue / 9525.0), MAX(12.0, cy.doubleValue / 9525.0),
            texto];
    }

    if (!cuerpo.length) return nil;

    NSString *fondo = [self firstMatch:@"<p:bg>.*?<a:srgbClr val=\"([0-9A-Fa-f]{6})\""
                                    in:xml group:1];
    if (!fondo.length) fondo = @"FFFFFF";

    NSString *css = [NSString stringWithFormat:
        @"html,body{margin:0;padding:0;background:#2b2b2b;}"
         @".slide{position:relative;width:%.1fpx;height:%.1fpx;background:#%@;"
         @"margin:0 auto;overflow:hidden;"
         @"font-family:'Helvetica Neue',Arial,sans-serif;color:#222;}"
         @".caja{position:absolute;overflow:hidden;}"
         @".caja p{margin:0 0 6px 0;line-height:1.25;}",
        tamano.width, tamano.height, fondo];

    NSString *html = [NSString stringWithFormat:@"<div class=\"slide\">%@</div>", cuerpo];
    return [self htmlDocument:html css:css ancho:(NSInteger)ceil(tamano.width)];
}

+ (NSString *)openDocumentHTMLAtPath:(NSString *)ruta {
    NSString *xml = [NSString stringWithContentsOfFile:ruta
                                             encoding:NSUTF8StringEncoding error:NULL];
    if (!xml.length) return nil;

    NSMutableString *cuerpo = [NSMutableString string];
    for (NSTextCheckingResult *m in [self matches:@"<text:(?:p|h)[^>]*>(.*?)</text:(?:p|h)>"
                                            in:xml]) {
        NSString *bloque = [xml substringWithRange:[m rangeAtIndex:1]];
        NSString *texto = [[self stripTags:bloque]
                           stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!texto.length) continue;
        [cuerpo appendFormat:@"<p>%@</p>", [self escapeHTML:texto]];
    }

    if (!cuerpo.length) return nil;

    NSString *css =
        @"html,body{margin:0;padding:24px;background:#fff;color:#111;}"
         @"body{font-family:Georgia,serif;font-size:12pt;line-height:1.5;}"
         @"p{margin:0 0 0.6em 0;}";
    return [self htmlDocument:cuerpo css:css ancho:800];
}

@end
