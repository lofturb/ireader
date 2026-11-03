#import <Foundation/Foundation.h>
#import "IRModels.h"
#import "IRSettings.h"

extern NSString * const IRLibraryDidChangeNotification;

@interface IRLibrary : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSArray<IRDocument *> *documents;
@property (nonatomic, readonly) NSArray<NSString *> *collections;

- (void)load;
- (void)save;

- (void)addDocument:(IRDocument *)document;
- (void)removeDocument:(IRDocument *)document;
- (IRDocument *)documentWithID:(NSString *)identifier;
- (IRDocument *)documentWithPath:(NSString *)path;

- (NSArray<IRDocument *> *)documentsMatchingQuery:(NSString *)query;
- (NSArray<IRDocument *> *)documentsInCollection:(NSString *)collection;
- (NSArray<IRDocument *> *)sortedDocuments:(NSArray<IRDocument *> *)docs
                                      key:(IRLibrarySortKey)key
                                ascending:(BOOL)ascending;

- (void)addCollection:(NSString *)name;
- (void)deleteCollection:(NSString *)name;
- (void)renameCollection:(NSString *)name to:(NSString *)newName;
- (void)setDocument:(IRDocument *)document inCollection:(NSString *)name added:(BOOL)added;

- (void)addReadingSeconds:(NSTimeInterval)seconds toDocument:(IRDocument *)document;
- (NSDictionary *)statistics;

- (void)saveCoverImage:(UIImage *)image forDocument:(IRDocument *)document;
- (void)deleteCoverForDocument:(IRDocument *)document;

@end
