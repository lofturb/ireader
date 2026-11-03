#import "IRModels.h"
#import "IRUtils.h"

@implementation IRProgress

- (instancetype)init {
    self = [super init];
    if (self) {
        _page = 1;
        _pageCount = 0;
        _ratio = 0;
        _zoom = 1;
        _offset = CGPointZero;
        _index = 0;
        _anchor = @"";
        _seconds = 0;
        _finished = NO;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"page": @(self.page),
        @"pageCount": @(self.pageCount),
        @"ratio": @(self.ratio),
        @"zoom": @(self.zoom),
        @"offsetX": @(self.offset.x),
        @"offsetY": @(self.offset.y),
        @"index": @(self.index),
        @"anchor": self.anchor ?: @"",
        @"seconds": @(self.seconds),
        @"finished": @(self.finished)
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _page = [dict[@"page"] integerValue] ?: 1;
        _pageCount = [dict[@"pageCount"] integerValue];
        _ratio = [dict[@"ratio"] doubleValue];
        _zoom = [dict[@"zoom"] doubleValue] ?: 1;
        _offset = CGPointMake([dict[@"offsetX"] doubleValue], [dict[@"offsetY"] doubleValue]);
        _index = [dict[@"index"] integerValue];
        _anchor = [dict[@"anchor"] copy] ?: @"";
        _seconds = [dict[@"seconds"] doubleValue];
        _finished = [dict[@"finished"] boolValue];
    }
    return self;
}

- (double)fraction {
    if (self.pageCount > 0) {
        double f = (double)self.page / (double)self.pageCount;
        return MAX(0, MIN(1, f));
    }
    return MAX(0, MIN(1, self.ratio));
}

@end

@implementation IRBookmark

+ (instancetype)bookmarkWithPage:(NSInteger)page
                           index:(NSInteger)index
                          anchor:(NSString *)anchor
                           label:(NSString *)label
                            note:(NSString *)note {
    IRBookmark *b = [[IRBookmark alloc] init];
    b.identifier = [[NSUUID UUID] UUIDString];
    b.page = page;
    b.index = index;
    b.anchor = anchor ?: @"";
    b.label = label ?: @"";
    b.note = note ?: @"";
    b.createdAt = [NSDate date];
    b.colorIndex = 0;
    return b;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.identifier ?: @"",
        @"page": @(self.page),
        @"index": @(self.index),
        @"anchor": self.anchor ?: @"",
        @"label": self.label ?: @"",
        @"note": self.note ?: @"",
        @"date": @([self.createdAt timeIntervalSince1970]),
        @"color": @(self.colorIndex)
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _identifier = [dict[@"id"] copy] ?: [[NSUUID UUID] UUIDString];
        _page = [dict[@"page"] integerValue];
        _index = [dict[@"index"] integerValue];
        _anchor = [dict[@"anchor"] copy] ?: @"";
        _label = [dict[@"label"] copy] ?: @"";
        _note = [dict[@"note"] copy] ?: @"";
        _createdAt = [NSDate dateWithTimeIntervalSince1970:[dict[@"date"] doubleValue]];
        _colorIndex = [dict[@"color"] integerValue];
    }
    return self;
}

@end

@implementation IRTOCItem

+ (instancetype)itemWithTitle:(NSString *)title page:(NSInteger)page
                        index:(NSInteger)index anchor:(NSString *)anchor
                         level:(NSInteger)level {
    IRTOCItem *i = [[IRTOCItem alloc] init];
    i.title = title ?: @"";
    i.page = page;
    i.index = index;
    i.anchor = anchor ?: @"";
    i.level = level;
    return i;
}

@end

@implementation IRSearchResult
@end

@implementation IRDocument

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
        _path = @"";
        _title = @"";
        _author = @"";
        _type = IRDocumentTypeUnknown;
        _fileSize = 0;
        _addedAt = [NSDate date];
        _lastOpenedAt = [NSDate date];
        _coverName = @"";
        _coverSeed = 0;
        _progress = [[IRProgress alloc] init];
        _bookmarks = [NSMutableArray array];
        _collections = [NSMutableArray array];
        _readingSeconds = 0;
        _favorite = NO;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *marcas = [NSMutableArray array];
    for (IRBookmark *b in self.bookmarks) {
        [marcas addObject:[b dictionaryRepresentation]];
    }
    return @{
        @"id": self.identifier ?: @"",
        @"path": self.path ?: @"",
        @"title": self.title ?: @"",
        @"author": self.author ?: @"",
        @"type": @(self.type),
        @"size": @(self.fileSize),
        @"added": @([self.addedAt timeIntervalSince1970]),
        @"opened": @([self.lastOpenedAt timeIntervalSince1970]),
        @"cover": self.coverName ?: @"",
        @"seed": @(self.coverSeed),
        @"progress": [self.progress dictionaryRepresentation],
        @"bookmarks": marcas,
        @"collections": self.collections ?: @[],
        @"seconds": @(self.readingSeconds),
        @"favorite": @(self.favorite)
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _identifier = [dict[@"id"] copy] ?: [[NSUUID UUID] UUIDString];
        _path = [dict[@"path"] copy] ?: @"";
        _title = [dict[@"title"] copy] ?: @"";
        _author = [dict[@"author"] copy] ?: @"";
        _type = (IRDocumentType)[dict[@"type"] integerValue];
        _fileSize = [dict[@"size"] unsignedLongLongValue];
        _addedAt = [NSDate dateWithTimeIntervalSince1970:[dict[@"added"] doubleValue]];
        _lastOpenedAt = [NSDate dateWithTimeIntervalSince1970:[dict[@"opened"] doubleValue]];
        _coverName = [dict[@"cover"] copy] ?: @"";
        _coverSeed = (NSUInteger)[dict[@"seed"] unsignedIntegerValue];
        _progress = [[IRProgress alloc] initWithDictionary:dict[@"progress"] ?: @{}];
        _bookmarks = [NSMutableArray array];
        for (NSDictionary *d in dict[@"bookmarks"] ?: @[]) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                [_bookmarks addObject:[[IRBookmark alloc] initWithDictionary:d]];
            }
        }
        _collections = [NSMutableArray array];
        for (NSString *c in dict[@"collections"] ?: @[]) {
            if ([c isKindOfClass:[NSString class]]) [_collections addObject:c];
        }
        _readingSeconds = [dict[@"seconds"] doubleValue];
        _favorite = [dict[@"favorite"] boolValue];
    }
    return self;
}

- (NSString *)displayAuthor {
    if (self.author.length) return self.author;
    return [IRUtils typeName:self.type];
}

- (NSString *)pageLabel {
    if (self.progress.pageCount > 0) {
        return [NSString stringWithFormat:@"Pág. %ld de %ld",
                (long)MAX(1, self.progress.page), (long)self.progress.pageCount];
    }
    return [NSString stringWithFormat:@"%d%%", (int)round([self.progress fraction] * 100)];
}

- (BOOL)isMissing {
    return ![[NSFileManager defaultManager] fileExistsAtPath:self.path];
}

- (NSString *)coverPath {
    if (!self.coverName.length) return nil;
    return [[IRUtils coversPath] stringByAppendingPathComponent:self.coverName];
}

- (void)touch {
    self.lastOpenedAt = [NSDate date];
}

@end
