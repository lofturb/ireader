#import <UIKit/UIKit.h>
#import "IRModels.h"

// Contenedor de lectura: barra superior, progreso, indice, marcadores y busqueda.
// Crea el controlador correcto segun el tipo de documento y guarda la posicion
// al recibir memoria baja, al pasar a segundo plano o al cerrar.
@interface IRReaderContainerViewController : UIViewController

- (instancetype)initWithDocument:(IRDocument *)document;

@property (nonatomic, strong) IRDocument *document;
@property (nonatomic, assign) NSInteger initialPage;   // 0 = la guardada
@property (nonatomic, copy) void (^onClose)(void);

@end
