#import "AppDelegate.h"
#import "IRRootViewController.h"
#import "IRTheme.h"
#import "IRSettings.h"
#import "IRLibrary.h"
#import "IRUtils.h"
#import "IRImportManager.h"

@interface AppDelegate ()
@property (nonatomic, assign) UIBackgroundTaskIdentifier tareaFondo;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [IRSettings shared];
    [IRLibrary shared];

    IRTheme *tema = [IRTheme shared];
    tema.dark = [IRSettings shared].appDark;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = tema.background;

    IRRootViewController *raiz = [[IRRootViewController alloc] init];
    self.window.rootViewController = raiz;
    [self.window makeKeyAndVisible];

    [self prepararDocumentos];
    [self aplicarAjustesDePantalla];

    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    if (url.isFileURL) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[IRImportManager shared] importFileAtPath:url.path completion:^(IRDocument *doc, NSError *error) {
                if (doc) [raiz openDocument:doc];
            }];
        });
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    return YES;
}

- (void)prepararDocumentos {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *docs = [IRUtils documentsPath];
    NSString *bienvenida = [docs stringByAppendingPathComponent:@"Bienvenido a IReader.txt"];
    if (![fm fileExistsAtPath:bienvenida]) {
        NSString *texto =
            @"IReader\n\n"
            @"Tu biblioteca personal para iPad.\n\n"
            @"Como empezar\n"
            @"1. Toca «Añadir» en la biblioteca para explorar los archivos del iPad.\n"
            @"2. Tambien puedes usar Wi-Fi: abre el panel lateral y entra en «Wi-Fi».\n"
            @"3. Desde el ordenador, arrastra tus PDF, EPUB, imagenes, CBZ o textos.\n\n"
            @"La app recuerda siempre la pagina exacta donde dejaste cada documento.\n"
            @"Los PDF se muestran con su tamano, margenes y tipografia originales.\n"
            @"Los EPUB, HTML y documentos de Office conservan su diseno siempre que sea posible.\n\n"
            @"Consejo: toca el centro de la pantalla mientras lees para mostrar los controles.\n";
        [texto writeToFile:bienvenida atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }

    // Recoge archivos dejados por iTunes/USB en Documents.
    NSArray *contenido = [fm contentsOfDirectoryAtPath:docs error:NULL];
    for (NSString *nombre in contenido) {
        if ([nombre hasPrefix:@"."]) continue;
        NSString *ruta = [docs stringByAppendingPathComponent:nombre];
        BOOL dir = NO;
        if ([fm fileExistsAtPath:ruta isDirectory:&dir] && dir) continue;
        if ([nombre isEqualToString:@"Bienvenido a IReader.txt"]) {
            if (![[IRLibrary shared] documentWithPath:ruta]) {
                [[IRImportManager shared] importFileAtPath:ruta move:NO completion:nil];
            }
            continue;
        }
        if ([IRUtils isSupportedPath:ruta] && ![nombre.pathExtension.lowercaseString isEqualToString:@"json"]) {
            [[IRImportManager shared] importFileAtPath:ruta move:NO completion:nil];
        }
    }
}

- (void)aplicarAjustesDePantalla {
    [UIApplication sharedApplication].idleTimerDisabled = [IRSettings shared].keepAwake;
    [UIApplication sharedApplication].statusBarStyle = [IRTheme shared].dark
        ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    if (!url.isFileURL) return NO;
    IRRootViewController *raiz = (IRRootViewController *)self.window.rootViewController;
    [[IRImportManager shared] importFileAtPath:url.path completion:^(IRDocument *doc, NSError *error) {
        if (doc) [raiz openDocument:doc];
    }];
    return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if (!url.isFileURL) return NO;
    IRRootViewController *raiz = (IRRootViewController *)self.window.rootViewController;
    [[IRImportManager shared] importFileAtPath:url.path completion:^(IRDocument *doc, NSError *error) {
        if (doc) [raiz openDocument:doc];
    }];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IRAppWillResignActiveNotification" object:nil];
    [[IRLibrary shared] save];
    [[IRSettings shared] save];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self aplicarAjustesDePantalla];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IRAppWillResignActiveNotification" object:nil];
    [[IRLibrary shared] save];

    self.tareaFondo = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.tareaFondo];
        self.tareaFondo = UIBackgroundTaskInvalid;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.tareaFondo != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.tareaFondo];
            self.tareaFondo = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"IRAppWillResignActiveNotification" object:nil];
    [[IRLibrary shared] save];
    [[IRSettings shared] save];
}

@end
