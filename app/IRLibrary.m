#import "IRLibrary.h"
#import "IRUtils.h"

NSString * const IRLibraryDidChangeNotification = @"IRLibraryDidChangeNotification";

@interface IRLibrary ()
@property (nonatomic, strong) NSMutableArray<IRDocument *> *mutableDocuments;
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableCollections;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *mutableFolderLibraries;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *dailySeconds;
@end

@implementation IRLibrary

+ (instancetype)shared {
    static IRLibrary *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IRLibrary alloc] init];
        [instancia load];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableDocuments = [NSMutableArray array];
        _mutableCollections = [NSMutableArray array];
        _mutableFolderLibraries = [NSMutableArray array];
        _dailySeconds = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<IRDocument *> *)documents { return [self.mutableDocuments copy]; }
- (NSArray<NSString *> *)collections { return [self.mutableCollections copy]; }
- (NSArray<NSDictionary *> *)folderLibraries { return [self.mutableFolderLibraries copy]; }

- (void)load {
    NSString *ruta = [IRUtils libraryFile];
    NSData *datos = [NSData dataWithContentsOfFile:ruta];
    if (!datos.length) {
        datos = [NSData dataWithContentsOfFile:[ruta stringByAppendingPathExtension:@"bak"]];
    }
    if (!datos.length) return;

    id objeto = [NSJSONSerialization JSONObjectWithData:datos options:0 error:NULL];
    if (!objeto) return;

    NSArray *docs = nil;
    if ([objeto isKindOfClass:[NSDictionary class]]) {
        docs = objeto[@"documents"];
        NSArray *cols = objeto[@"collections"];
        NSArray *libs = objeto[@"libraries"];
        NSDictionary *diario = objeto[@"daily"];
        if ([cols isKindOfClass:[NSArray class]]) {
            for (id c in cols) if ([c isKindOfClass:[NSString class]]) [self.mutableCollections addObject:c];
        }
        if ([libs isKindOfClass:[NSArray class]]) {
            for (id l in libs) {
                if (![l isKindOfClass:[NSDictionary class]]) continue;
                NSString *nombre = l[@"name"];
                NSString *ruta = l[@"path"];
                if ([nombre isKindOfClass:[NSString class]] && [ruta isKindOfClass:[NSString class]] &&
                    nombre.length && ruta.length) {
                    [self.mutableFolderLibraries addObject:@{@"name": nombre, @"path": ruta}];
                }
            }
        }
        if ([diario isKindOfClass:[NSDictionary class]]) {
            [diario enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
                if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSNumber class]]) {
                    self.dailySeconds[key] = value;
                }
            }];
        }
    } else if ([objeto isKindOfClass:[NSArray class]]) {
        docs = objeto;
    }

    if ([docs isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in docs) {
            if (![d isKindOfClass:[NSDictionary class]]) continue;
            IRDocument *doc = [[IRDocument alloc] initWithDictionary:d];
            if (doc.path.length) [self.mutableDocuments addObject:doc];
        }
    }
}

- (void)save {
    NSMutableArray *docs = [NSMutableArray array];
    for (IRDocument *d in self.mutableDocuments) {
        [docs addObject:[d dictionaryRepresentation]];
    }
    NSDictionary *raiz = @{
        @"version": @1,
        @"documents": docs,
        @"collections": self.mutableCollections ?: @[],
        @"libraries": self.mutableFolderLibraries ?: @[],
        @"daily": self.dailySeconds ?: @{}
    };
    NSData *datos = [NSJSONSerialization dataWithJSONObject:raiz
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:NULL];
    if (!datos) return;
    NSString *ruta = [IRUtils libraryFile];
    NSString *bak = [ruta stringByAppendingPathExtension:@"bak"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:ruta]) {
        [fm removeItemAtPath:bak error:NULL];
        [fm copyItemAtPath:ruta toPath:bak error:NULL];
    }
    [datos writeToFile:ruta options:NSDataWritingAtomic error:NULL];
}

- (void)notify {
    [[NSNotificationCenter defaultCenter] postNotificationName:IRLibraryDidChangeNotification object:self];
}

- (void)addDocument:(IRDocument *)document {
    if (!document || !document.path.length) return;
    IRDocument *existente = [self documentWithPath:document.path];
    if (existente) {
        existente.lastOpenedAt = [NSDate date];
        [self save];
        [self notify];
        return;
    }
    if (!document.identifier.length) document.identifier = [[NSUUID UUID] UUIDString];
    [self.mutableDocuments addObject:document];
    [self save];
    [self notify];
}

- (void)removeDocument:(IRDocument *)document {
    if (!document) return;
    [self.mutableDocuments removeObject:document];
    [self deleteCoverForDocument:document];
    [self save];
    [self notify];
}

- (IRDocument *)documentWithID:(NSString *)identifier {
    if (!identifier.length) return nil;
    for (IRDocument *d in self.mutableDocuments) {
        if ([d.identifier isEqualToString:identifier]) return d;
    }
    return nil;
}

- (IRDocument *)documentWithPath:(NSString *)path {
    if (!path.length) return nil;
    NSString *normal = [path stringByStandardizingPath];
    for (IRDocument *d in self.mutableDocuments) {
        if ([[d.path stringByStandardizingPath] isEqualToString:normal]) return d;
    }
    return nil;
}

- (NSArray<IRDocument *> *)documentsMatchingQuery:(NSString *)query {
    if (!query.length) return [self.documents copy];
    NSString *q = [query lowercaseString];
    NSMutableArray *salida = [NSMutableArray array];
    for (IRDocument *d in self.mutableDocuments) {
        NSString *texto = [NSString stringWithFormat:@"%@ %@ %@ %@",
                           d.title ?: @"", d.author ?: @"", d.path ?: @"",
                           [d.collections componentsJoinedByString:@" "]];
        if ([[texto lowercaseString] rangeOfString:q].location != NSNotFound) {
            [salida addObject:d];
        }
    }
    return salida;
}

- (NSArray<IRDocument *> *)documentsInCollection:(NSString *)collection {
    if (!collection.length) return [self.documents copy];
    NSMutableArray *salida = [NSMutableArray array];
    for (IRDocument *d in self.mutableDocuments) {
        if ([d.collections containsObject:collection]) [salida addObject:d];
    }
    return salida;
}

- (NSArray<IRDocument *> *)sortedDocuments:(NSArray<IRDocument *> *)docs
                                      key:(IRLibrarySortKey)key
                                ascending:(BOOL)ascending {
    NSArray *copia = [docs sortedArrayUsingComparator:^NSComparisonResult(IRDocument *a, IRDocument *b) {
        NSComparisonResult r = NSOrderedSame;
        switch (key) {
            case IRLibrarySortRecent:
                r = [b.lastOpenedAt compare:a.lastOpenedAt];
                break;
            case IRLibrarySortTitle:
                r = [IRUtils naturalCompare:a.title with:b.title];
                break;
            case IRLibrarySortAuthor:
                r = [IRUtils naturalCompare:a.displayAuthor with:b.displayAuthor];
                break;
            case IRLibrarySortAdded:
                r = [b.addedAt compare:a.addedAt];
                break;
        }
        return ascending ? r : (r == NSOrderedAscending ? NSOrderedDescending :
                                (r == NSOrderedDescending ? NSOrderedAscending : NSOrderedSame));
    }];
    return copia;
}

#pragma mark - Bibliotecas de carpeta

- (void)addFolderLibraryNamed:(NSString *)name path:(NSString *)path {
    NSString *n = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!n.length || !path.length) return;
    NSString *normal = [path stringByStandardizingPath];
    for (NSDictionary *lib in self.mutableFolderLibraries) {
        if ([lib[@"name"] isEqualToString:n]) {
            NSUInteger idx = [self.mutableFolderLibraries indexOfObject:lib];
            if (idx != NSNotFound) {
                self.mutableFolderLibraries[idx] = @{@"name": n, @"path": normal};
            }
            [self save];
            [self notify];
            return;
        }
    }
    [self.mutableFolderLibraries addObject:@{@"name": n, @"path": normal}];
    [self save];
    [self notify];
}

- (void)removeFolderLibraryNamed:(NSString *)name {
    if (!name.length) return;
    for (NSDictionary *lib in [self.mutableFolderLibraries copy]) {
        if ([lib[@"name"] isEqualToString:name]) {
            [self.mutableFolderLibraries removeObject:lib];
        }
    }
    [self save];
    [self notify];
}

- (NSString *)pathForFolderLibraryNamed:(NSString *)name {
    for (NSDictionary *lib in self.mutableFolderLibraries) {
        if ([lib[@"name"] isEqualToString:name]) return lib[@"path"];
    }
    return nil;
}

- (IRDocument *)indexDocumentAtPath:(NSString *)path {
    if (!path.length) return nil;
    IRDocument *existente = [self documentWithPath:path];
    if (existente) return existente;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if (!attrs) return nil;
    IRDocument *doc = [[IRDocument alloc] init];
    doc.path = [path stringByStandardizingPath];
    doc.title = [[doc.path lastPathComponent] stringByDeletingPathExtension];
    doc.author = @"";
    doc.type = [IRUtils typeForPath:doc.path];
    doc.fileSize = [attrs[NSFileSize] unsignedLongLongValue];
    doc.addedAt = [NSDate date];
    doc.lastOpenedAt = [NSDate date];
    doc.coverSeed = (NSUInteger)([[IRUtils sha1OfString:doc.path] hash] % 997);
    doc.identifier = [[NSUUID UUID] UUIDString];
    [self.mutableDocuments addObject:doc];
    return doc;
}

- (void)addCollection:(NSString *)name {
    NSString *n = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!n.length) return;
    if ([self.mutableCollections containsObject:n]) return;
    [self.mutableCollections addObject:n];
    [self save];
    [self notify];
}

- (void)deleteCollection:(NSString *)name {
    if (!name.length) return;
    [self.mutableCollections removeObject:name];
    for (IRDocument *d in self.mutableDocuments) {
        [d.collections removeObject:name];
    }
    [self save];
    [self notify];
}

- (void)renameCollection:(NSString *)name to:(NSString *)newName {
    NSString *n = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!name.length || !n.length) return;
    NSUInteger idx = [self.mutableCollections indexOfObject:name];
    if (idx == NSNotFound) return;
    [self.mutableCollections replaceObjectAtIndex:idx withObject:n];
    for (IRDocument *d in self.mutableDocuments) {
        NSUInteger i = [d.collections indexOfObject:name];
        if (i != NSNotFound) [d.collections replaceObjectAtIndex:i withObject:n];
    }
    [self save];
    [self notify];
}

- (void)setDocument:(IRDocument *)document inCollection:(NSString *)name added:(BOOL)added {
    if (!document || !name.length) return;
    if (added) {
        if (![document.collections containsObject:name]) [document.collections addObject:name];
    } else {
        [document.collections removeObject:name];
    }
    [self save];
    [self notify];
}

- (void)addReadingSeconds:(NSTimeInterval)seconds toDocument:(IRDocument *)document {
    if (seconds <= 0) return;
    if (document) document.readingSeconds += seconds;
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"yyyy-MM-dd";
    NSString *dia = [f stringFromDate:[NSDate date]];
    double actual = [self.dailySeconds[dia] doubleValue];
    self.dailySeconds[dia] = @(actual + seconds);
    [self save];
}

- (NSDictionary *)statistics {
    double total = 0;
    NSInteger terminados = 0;
    NSInteger leyendo = 0;
    NSInteger paginas = 0;
    for (IRDocument *d in self.mutableDocuments) {
        total += d.readingSeconds;
        if (d.progress.finished) terminados++;
        else if (d.progress.page > 1 || d.progress.ratio > 0.01) leyendo++;
        if (d.progress.pageCount > 0) paginas += MIN(d.progress.page, d.progress.pageCount);
    }
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"yyyy-MM-dd";
    double hoy = [self.dailySeconds[[f stringFromDate:[NSDate date]]] doubleValue];

    // Racha: dias consecutivos con lectura, empezando hoy o ayer.
    NSInteger racha = 0;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *dia = [NSDate date];
    for (int i = 0; i < 3650; i++) {
        NSString *clave = [f stringFromDate:dia];
        if ([self.dailySeconds[clave] doubleValue] > 0) {
            racha++;
            dia = [cal dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:dia options:0];
        } else {
            if (i == 0) {
                dia = [cal dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:dia options:0];
                continue;
            }
            break;
        }
    }

    return @{
        @"seconds": @(total),
        @"today": @(hoy),
        @"finished": @(terminados),
        @"reading": @(leyendo),
        @"pages": @(paginas),
        @"books": @(self.mutableDocuments.count),
        @"streak": @(racha)
    };
}

- (void)saveCoverImage:(UIImage *)image forDocument:(IRDocument *)document {
    if (!image || !document) return;
    NSString *nombre = [NSString stringWithFormat:@"%@.jpg", document.identifier];
    NSString *ruta = [[IRUtils coversPath] stringByAppendingPathComponent:nombre];
    NSData *datos = UIImageJPEGRepresentation(image, 0.86);
    if ([datos writeToFile:ruta options:NSDataWritingAtomic error:NULL]) {
        document.coverName = nombre;
    }
}

- (void)deleteCoverForDocument:(IRDocument *)document {
    if (!document.coverName.length) return;
    NSString *ruta = [document coverPath];
    if (ruta.length) [[NSFileManager defaultManager] removeItemAtPath:ruta error:NULL];
    document.coverName = @"";
}

@end
