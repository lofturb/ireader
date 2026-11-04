#import <UIKit/UIKit.h>
#import "IRModels.h"

@interface IRFileBrowserViewController : UIViewController

@property (nonatomic, copy) void (^onImport)(IRDocument *document);
@property (nonatomic, copy) NSString *startPath;
// Modo "elegir carpeta": no importa archivos, devuelve la ruta elegida.
@property (nonatomic, assign) BOOL picksFolder;
@property (nonatomic, copy) void (^onPickFolder)(NSString *path);

@end
