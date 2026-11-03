#import <Foundation/Foundation.h>
#import "IRModels.h"

// EPUB 2/3: extrae el libro a cache, lee OPF/NCX/nav y expone el spine.
// No reescribe el contenido: el lector carga cada XHTML con su CSS, fuentes e
// imagenes originales.
@interface IREPUBDocument : NSObject

+ (instancetype)documentAtPath:(NSString *)path error:(NSError **)error;

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *opfPath;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *author;
@property (nonatomic, copy, readonly) NSString *language;
@property (nonatomic, copy, readonly) NSString *publisher;
@property (nonatomic, copy, readonly) NSString *bookDescription;
@property (nonatomic, copy, readonly) NSString *coverPath;
@property (nonatomic, assign, readonly) BOOL fixedLayout;
@property (nonatomic, assign, readonly) BOOL pageProgressionRTL;

@property (nonatomic, strong, readonly) NSArray<NSDictionary *> *spine;
@property (nonatomic, strong, readonly) NSArray<IRTOCItem *> *toc;
@property (nonatomic, readonly) NSInteger chapterCount;

- (NSDictionary *)spineItemAtIndex:(NSInteger)index;
- (NSString *)filePathForSpineIndex:(NSInteger)index;
- (NSString *)chapterTitleAtIndex:(NSInteger)index;
- (NSInteger)indexForHref:(NSString *)href;

@end
