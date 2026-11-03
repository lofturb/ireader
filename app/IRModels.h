#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IRDocumentType) {
    IRDocumentTypeUnknown = 0,
    IRDocumentTypePDF,
    IRDocumentTypeEPUB,
    IRDocumentTypeText,
    IRDocumentTypeImage,
    IRDocumentTypeComic,
    IRDocumentTypeOffice,
    IRDocumentTypeHTML,
    IRDocumentTypeMedia,
    IRDocumentTypeArchive,
    IRDocumentTypeFolder
};

@class IRBookmark;

@interface IRProgress : NSObject

@property (nonatomic, assign) NSInteger page;        // 1-based
@property (nonatomic, assign) NSInteger pageCount;
@property (nonatomic, assign) double ratio;          // 0..1
@property (nonatomic, assign) double zoom;
@property (nonatomic, assign) CGPoint offset;        // desplazamiento normalizado 0..1
@property (nonatomic, assign) NSInteger index;       // capitulo / imagen / diapositiva
@property (nonatomic, copy)   NSString *anchor;      // texto visible para reanudar EPUB/HTML
@property (nonatomic, assign) double seconds;        // multimedia
@property (nonatomic, assign) BOOL finished;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (double)fraction;

@end

@interface IRBookmark : NSObject

@property (nonatomic, copy)   NSString *identifier;
@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, copy)   NSString *anchor;
@property (nonatomic, copy)   NSString *label;
@property (nonatomic, copy)   NSString *note;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, assign) NSInteger colorIndex;

+ (instancetype)bookmarkWithPage:(NSInteger)page
                           index:(NSInteger)index
                          anchor:(NSString *)anchor
                           label:(NSString *)label
                            note:(NSString *)note;
- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

@interface IRTOCItem : NSObject

@property (nonatomic, copy)   NSString *title;
@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, copy)   NSString *anchor;
@property (nonatomic, assign) NSInteger level;

+ (instancetype)itemWithTitle:(NSString *)title page:(NSInteger)page
                        index:(NSInteger)index anchor:(NSString *)anchor
                         level:(NSInteger)level;

@end

@interface IRSearchResult : NSObject

@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, copy)   NSString *quote;
@property (nonatomic, copy)   NSString *snippet;
@property (nonatomic, assign) NSRange range;

@end

@interface IRDocument : NSObject

@property (nonatomic, copy)   NSString *identifier;
@property (nonatomic, copy)   NSString *path;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *author;
@property (nonatomic, assign) IRDocumentType type;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, strong) NSDate *addedAt;
@property (nonatomic, strong) NSDate *lastOpenedAt;
@property (nonatomic, copy)   NSString *coverName;
@property (nonatomic, assign) NSUInteger coverSeed;
@property (nonatomic, strong) IRProgress *progress;
@property (nonatomic, strong) NSMutableArray<IRBookmark *> *bookmarks;
@property (nonatomic, strong) NSMutableArray<NSString *> *collections;
@property (nonatomic, assign) double readingSeconds;
@property (nonatomic, assign) BOOL favorite;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSString *)displayAuthor;
- (NSString *)pageLabel;
- (BOOL)isMissing;
- (NSString *)coverPath;
- (void)touch;

@end

@protocol IRReader <NSObject>

- (void)saveProgressNow;
- (NSString *)pageLabel;
- (NSInteger)pageCount;
- (NSInteger)currentPage;
- (void)goToPage:(NSInteger)page;
- (NSArray<IRTOCItem *> *)tableOfContents;
- (void)jumpToTOCItem:(IRTOCItem *)item;
- (BOOL)supportsBookmarks;
- (void)addBookmarkWithNote:(NSString *)note;
- (BOOL)supportsSearch;
- (void)search:(NSString *)query completion:(void (^)(NSArray<IRSearchResult *> *results))completion;
- (void)jumpToSearchResult:(IRSearchResult *)result;
- (void)applyDisplaySettings;
- (BOOL)isPaginated;

@end
