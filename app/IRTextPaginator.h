#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Pagina un texto con TextKit sin recortar palabras: cada pagina es un rango de
// caracteres que se puede guardar y restaurar con exactitud.
@interface IRTextPaginator : NSObject

- (instancetype)initWithAttributedString:(NSAttributedString *)text size:(CGSize)size;

@property (nonatomic, readonly) NSInteger pageCount;
@property (nonatomic, readonly) NSUInteger characterCount;

- (NSRange)characterRangeForPage:(NSInteger)page;   // pagina 1-based
- (NSInteger)pageForCharacterIndex:(NSUInteger)index; // 1-based
- (NSAttributedString *)attributedStringForPage:(NSInteger)page;
- (NSString *)plainTextForPage:(NSInteger)page;

@end
