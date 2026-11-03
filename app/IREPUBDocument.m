#import "IREPUBDocument.h"
#import "IRArchive.h"
#import "IRUtils.h"

typedef NS_ENUM(NSInteger, IREPUBParseMode) {
    IREPUBParseModeNone = 0,
    IREPUBParseModeContainer,
    IREPUBParseModeOPF,
    IREPUBParseModeNCX,
    IREPUBParseModeNAV
};

@interface IREPUBDocument () <NSXMLParserDelegate>
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic, copy) NSString *opfPath;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *publisher;
@property (nonatomic, copy) NSString *bookDescription;
@property (nonatomic, copy) NSString *coverPath;
@property (nonatomic, assign) BOOL fixedLayout;
@property (nonatomic, assign) BOOL pageProgressionRTL;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *spine;
@property (nonatomic, strong) NSMutableArray<IRTOCItem *> *toc;

@property (nonatomic, assign) IREPUBParseMode parseMode;
@property (nonatomic, copy) NSString *containerRootPath;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *manifest;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *spineRefs;
@property (nonatomic, copy) NSString *spineTOCID;
@property (nonatomic, copy) NSString *coverID;
@property (nonatomic, copy) NSString *guideCoverHref;
@property (nonatomic, copy) NSString *currentText;
@property (nonatomic, copy) NSString *currentTextKey;
@property (nonatomic, copy) NSString *currentMetaProperty;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *tocFlat;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *tocStack;
@property (nonatomic, assign) BOOL inTOCNav;
@property (nonatomic, assign) NSInteger navDepth;
@property (nonatomic, strong) NSMutableDictionary *navCurrent;
@property (nonatomic, assign) BOOL capturingNavText;
@property (nonatomic, copy) NSString *tocBaseDir;
@end

@implementation IREPUBDocument

+ (instancetype)documentAtPath:(NSString *)path error:(NSError **)error {
    if (!path.length) {
        if (error) *error = [NSError errorWithDomain:@"IREPUB" code:1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Ruta vacía"}];
        return nil;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:NULL];
    unsigned long long tam = [attrs fileSize];
    NSDate *fecha = attrs[NSFileModificationDate] ?: [NSDate date];
    NSString *firma = [NSString stringWithFormat:@"%@|%llu|%.0f", path, tam, [fecha timeIntervalSince1970]];
    NSString *cache = [[IRUtils epubCachePath] stringByAppendingPathComponent:[IRUtils sha1OfString:firma]];
    NSString *container = [cache stringByAppendingPathComponent:@"META-INF/container.xml"];

    if (![fm fileExistsAtPath:container]) {
        [fm removeItemAtPath:cache error:NULL];
        [fm createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:nil error:NULL];
        if (![IRArchive extractArchive:path toDirectory:cache progress:nil cancel:nil error:error]) {
            return nil;
        }
    }

    IREPUBDocument *doc = [[IREPUBDocument alloc] init];
    doc.path = path;
    doc.rootPath = cache;
    doc.manifest = [NSMutableDictionary dictionary];
    doc.spineRefs = [NSMutableArray array];
    doc.spine = [NSMutableArray array];
    doc.toc = [NSMutableArray array];
    doc.tocFlat = [NSMutableArray array];
    doc.tocStack = [NSMutableArray array];

    if (![doc parseXMLAtPath:container mode:IREPUBParseModeContainer] || !doc.containerRootPath.length) {
        if (error) *error = [NSError errorWithDomain:@"IREPUB" code:2
                                            userInfo:@{NSLocalizedDescriptionKey: @"EPUB sin container.xml válido"}];
        return nil;
    }

    NSString *opf = [[cache stringByAppendingPathComponent:doc.containerRootPath] stringByStandardizingPath];
    if (![opf hasPrefix:cache]) {
        if (error) *error = [NSError errorWithDomain:@"IREPUB" code:3
                                            userInfo:@{NSLocalizedDescriptionKey: @"Ruta OPF no válida"}];
        return nil;
    }
    doc.opfPath = opf;
    if (![doc parseXMLAtPath:opf mode:IREPUBParseModeOPF]) {
        if (error) *error = [NSError errorWithDomain:@"IREPUB" code:4
                                            userInfo:@{NSLocalizedDescriptionKey: @"No se pudo leer el OPF"}];
        return nil;
    }

    [doc buildSpine];
    [doc parseTOC];
    [doc resolveCover];
    [doc deobfuscateFontsIfNeeded];

    if (!doc.title.length) {
        doc.title = [[path lastPathComponent] stringByDeletingPathExtension];
    }
    if (!doc.author.length) doc.author = @"";
    return doc;
}

#pragma mark - Extraccion

- (BOOL)parseXMLAtPath:(NSString *)path mode:(IREPUBParseMode)mode {
    NSData *datos = [NSData dataWithContentsOfFile:path];
    if (!datos.length) return NO;
    NSXMLParser *p = [[NSXMLParser alloc] initWithData:datos];
    p.delegate = self;
    self.parseMode = mode;
    self.currentText = @"";
    self.currentTextKey = nil;
    return [p parse];
}

#pragma mark - Construccion

- (void)buildSpine {
    [self.spine removeAllObjects];
    NSString *opfDir = [self.opfPath stringByDeletingLastPathComponent];
    for (NSDictionary *ref in self.spineRefs) {
        NSString *idref = ref[@"idref"];
        NSDictionary *item = self.manifest[idref];
        if (!item) continue;
        NSString *href = item[@"href"];
        if (!href.length) continue;
        NSString *full = [[opfDir stringByAppendingPathComponent:href] stringByStandardizingPath];
        if (![full hasPrefix:self.rootPath]) continue;
        NSString *linear = ref[@"linear"] ?: @"yes";
        [self.spine addObject:@{
            @"idref": idref ?: @"",
            @"href": href,
            @"fullPath": full,
            @"mediaType": item[@"mediaType"] ?: @"",
            @"properties": item[@"properties"] ?: @"",
            @"linear": @(![linear isEqualToString:@"no"])
        }];
    }
}

- (void)parseTOC {
    [self.toc removeAllObjects];
    [self.tocFlat removeAllObjects];

    NSString *navHref = nil;
    NSString *ncxHref = nil;
    for (NSString *key in self.manifest) {
        NSDictionary *item = self.manifest[key];
        NSString *props = item[@"properties"] ?: @"";
        if ([props rangeOfString:@"nav"].location != NSNotFound) {
            navHref = item[@"href"];
            break;
        }
    }
    if (self.spineTOCID.length) {
        ncxHref = self.manifest[self.spineTOCID][@"href"];
    }
    NSString *opfDir = [self.opfPath stringByDeletingLastPathComponent];

    if (navHref.length) {
        NSString *ruta = [[opfDir stringByAppendingPathComponent:navHref] stringByStandardizingPath];
        self.tocBaseDir = [ruta stringByDeletingLastPathComponent];
        [self parseXMLAtPath:ruta mode:IREPUBParseModeNAV];
    }
    if (self.tocFlat.count == 0 && ncxHref.length) {
        NSString *ruta = [[opfDir stringByAppendingPathComponent:ncxHref] stringByStandardizingPath];
        self.tocBaseDir = [ruta stringByDeletingLastPathComponent];
        [self parseXMLAtPath:ruta mode:IREPUBParseModeNCX];
    }

    if (self.tocFlat.count == 0) {
        NSInteger i = 0;
        for (NSDictionary *s in self.spine) {
            NSString *nombre = [[s[@"fullPath"] lastPathComponent] stringByDeletingPathExtension];
            [self.toc addObject:[IRTOCItem itemWithTitle:nombre page:i + 1 index:i anchor:@"" level:0]];
            i++;
        }
        return;
    }

    for (NSDictionary *d in self.tocFlat) {
        NSString *href = d[@"href"] ?: @"";
        NSString *titulo = d[@"title"] ?: @"";
        NSInteger nivel = [d[@"level"] integerValue];
        NSString *sinFragmento = href;
        NSString *ancla = @"";
        NSRange hash = [href rangeOfString:@"#"];
        if (hash.location != NSNotFound) {
            sinFragmento = [href substringToIndex:hash.location];
            ancla = [href substringFromIndex:hash.location + 1];
        }
        sinFragmento = [sinFragmento stringByRemovingPercentEncoding] ?: sinFragmento;
        NSString *completo = [[self.tocBaseDir stringByAppendingPathComponent:sinFragmento] stringByStandardizingPath];
        NSInteger idx = [self spineIndexForFullPath:completo];
        if (idx < 0) {
            completo = [[opfDir stringByAppendingPathComponent:sinFragmento] stringByStandardizingPath];
            idx = [self spineIndexForFullPath:completo];
        }
        if (idx < 0) continue;
        if (!titulo.length) titulo = [NSString stringWithFormat:@"Capítulo %ld", (long)idx + 1];
        [self.toc addObject:[IRTOCItem itemWithTitle:titulo page:idx + 1 index:idx anchor:ancla level:nivel]];
    }
}

- (NSInteger)spineIndexForFullPath:(NSString *)path {
    for (NSInteger i = 0; i < (NSInteger)self.spine.count; i++) {
        NSString *p = self.spine[(NSUInteger)i][@"fullPath"];
        if ([[p stringByStandardizingPath] isEqualToString:[path stringByStandardizingPath]]) return i;
    }
    return -1;
}

- (void)resolveCover {
    NSString *opfDir = [self.opfPath stringByDeletingLastPathComponent];
    NSString *href = nil;
    if (self.coverID.length) href = self.manifest[self.coverID][@"href"];
    if (!href.length) {
        for (NSString *key in self.manifest) {
            NSDictionary *item = self.manifest[key];
            NSString *props = item[@"properties"] ?: @"";
            if ([props rangeOfString:@"cover-image"].location != NSNotFound) {
                href = item[@"href"];
                break;
            }
        }
    }
    if (!href.length && self.guideCoverHref.length) href = self.guideCoverHref;
    if (!href.length) {
        for (NSString *key in self.manifest) {
            NSDictionary *item = self.manifest[key];
            NSString *media = item[@"mediaType"] ?: @"";
            if ([media hasPrefix:@"image/"]) { href = item[@"href"]; break; }
        }
    }
    if (!href.length) return;
    NSString *ruta = [[opfDir stringByAppendingPathComponent:[href stringByRemovingPercentEncoding] ?: href] stringByStandardizingPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:ruta]) self.coverPath = ruta;
}

// Las fuentes EPUB pueden venir ofuscadas con el algoritmo IDPF. Se desofuscan
// en la cache para que WebKit use la tipografia original del libro.
- (void)deobfuscateFontsIfNeeded {
    NSString *enc = [[self.rootPath stringByAppendingPathComponent:@"META-INF/encryption.xml"] copy];
    if (![[NSFileManager defaultManager] fileExistsAtPath:enc]) return;
    NSData *datos = [NSData dataWithContentsOfFile:enc];
    if (!datos.length) return;
    NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    if (!texto.length) return;
    // Extraccion sencilla de CipherReference URI y algoritmo.
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"<enc:EncryptionMethod[^>]*Algorithm=\"([^\"]+)\"[^>]*>.*?<enc:CipherReference[^>]*URI=\"([^\"]+)\""
        options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSArray *matches = [re matchesInString:texto options:0 range:NSMakeRange(0, texto.length)];
    if (!matches.count) {
        // Variante sin prefijo enc:.
        re = [NSRegularExpression regularExpressionWithPattern:
            @"<EncryptionMethod[^>]*Algorithm=\"([^\"]+)\"[^>]*>.*?<CipherReference[^>]*URI=\"([^\"]+)\""
            options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
        matches = [re matchesInString:texto options:0 range:NSMakeRange(0, texto.length)];
    }
    if (!matches.count) return;

    NSString *identificador = [self identifierFromOPF];
    if (!identificador.length) return;
    NSData *clave = [self sha1DataOfString:identificador];

    for (NSTextCheckingResult *m in matches) {
        if (m.numberOfRanges < 3) continue;
        NSString *alg = [texto substringWithRange:[m rangeAtIndex:1]];
        NSString *uri = [texto substringWithRange:[m rangeAtIndex:2]];
        if ([alg rangeOfString:@"embedding"].location == NSNotFound &&
            [alg rangeOfString:@"idpf"].location == NSNotFound) continue;
        NSString *ruta = [[self.rootPath stringByAppendingPathComponent:[uri stringByRemovingPercentEncoding] ?: uri] stringByStandardizingPath];
        if (![ruta hasPrefix:self.rootPath]) continue;
        NSMutableData *archivo = [NSMutableData dataWithContentsOfFile:ruta];
        if (!archivo.length || clave.length == 0) continue;
        uint8_t *bytes = archivo.mutableBytes;
        const uint8_t *k = clave.bytes;
        NSUInteger limite = MIN((NSUInteger)1040, archivo.length);
        for (NSUInteger i = 0; i < limite; i++) {
            bytes[i] ^= k[i % clave.length];
        }
        [archivo writeToFile:ruta options:NSDataWritingAtomic error:NULL];
    }
}

- (NSString *)identifierFromOPF {
    NSData *datos = [NSData dataWithContentsOfFile:self.opfPath];
    if (!datos.length) return nil;
    NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    if (!texto.length) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"<dc:identifier[^>]*>(.*?)</dc:identifier>" options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:texto options:0 range:NSMakeRange(0, texto.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    return [[texto substringWithRange:[m rangeAtIndex:1]]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSData *)sha1DataOfString:(NSString *)string {
    NSData *d = [string dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[20];
    CC_SHA1(d.bytes, (CC_LONG)d.length, digest);
    return [NSData dataWithBytes:digest length:20];
}

#pragma mark - Consultas

- (NSInteger)chapterCount { return (NSInteger)self.spine.count; }

- (NSDictionary *)spineItemAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.spine.count) return nil;
    return self.spine[(NSUInteger)index];
}

- (NSString *)filePathForSpineIndex:(NSInteger)index {
    return [self spineItemAtIndex:index][@"fullPath"];
}

- (NSString *)chapterTitleAtIndex:(NSInteger)index {
    for (IRTOCItem *item in self.toc) {
        if (item.index == index && item.level <= 1) return item.title;
    }
    for (IRTOCItem *item in self.toc) {
        if (item.index == index) return item.title;
    }
    return [NSString stringWithFormat:@"Capítulo %ld", (long)index + 1];
}

- (NSInteger)indexForHref:(NSString *)href {
    if (!href.length) return -1;
    NSString *sin = href;
    NSRange hash = [href rangeOfString:@"#"];
    if (hash.location != NSNotFound) sin = [href substringToIndex:hash.location];
    sin = [sin stringByRemovingPercentEncoding] ?: sin;
    NSString *opfDir = [self.opfPath stringByDeletingLastPathComponent];
    NSString *full = [[opfDir stringByAppendingPathComponent:sin] stringByStandardizingPath];
    NSInteger idx = [self spineIndexForFullPath:full];
    if (idx < 0 && self.tocBaseDir.length) {
        full = [[self.tocBaseDir stringByAppendingPathComponent:sin] stringByStandardizingPath];
        idx = [self spineIndexForFullPath:full];
    }
    return idx;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributes {
    NSString *name = elementName;
    if (qName.length) name = [qName componentsSeparatedByString:@":"].lastObject;
    if (namespaceURI.length && elementName.length) name = elementName;

    if (self.parseMode == IREPUBParseModeContainer) {
        if ([name isEqualToString:@"rootfile"]) {
            self.containerRootPath = attributes[@"full-path"];
        }
        return;
    }

    if (self.parseMode == IREPUBParseModeOPF) {
        if ([name isEqualToString:@"item"]) {
            NSString *ident = attributes[@"id"];
            if (ident.length) {
                self.manifest[ident] = @{
                    @"id": ident,
                    @"href": attributes[@"href"] ?: @"",
                    @"mediaType": attributes[@"media-type"] ?: @"",
                    @"properties": attributes[@"properties"] ?: @""
                };
            }
        } else if ([name isEqualToString:@"itemref"]) {
            NSString *idref = attributes[@"idref"];
            if (idref.length) {
                [self.spineRefs addObject:@{@"idref": idref,
                                            @"linear": attributes[@"linear"] ?: @"yes"}];
            }
        } else if ([name isEqualToString:@"spine"]) {
            NSString *ppd = attributes[@"page-progression-direction"];
            if ([ppd isEqualToString:@"rtl"]) self.pageProgressionRTL = YES;
            NSString *toc = attributes[@"toc"];
            if (toc.length) self.spineTOCID = toc;
        } else if ([name isEqualToString:@"meta"]) {
            NSString *metaName = attributes[@"name"];
            NSString *content = attributes[@"content"];
            NSString *property = attributes[@"property"];
            if ([metaName isEqualToString:@"cover"] && content.length) self.coverID = content;
            if (property.length) {
                self.currentMetaProperty = property;
                if (content.length) [self applyMetaProperty:property value:content];
                self.currentText = @"";
            }
        } else if ([name isEqualToString:@"reference"]) {
            if ([attributes[@"type"] isEqualToString:@"cover"]) {
                self.guideCoverHref = attributes[@"href"];
            }
        } else if ([name isEqualToString:@"title"] || [name isEqualToString:@"creator"] ||
                   [name isEqualToString:@"language"] || [name isEqualToString:@"description"] ||
                   [name isEqualToString:@"publisher"]) {
            self.currentTextKey = name;
            self.currentText = @"";
        }
        return;
    }

    if (self.parseMode == IREPUBParseModeNCX) {
        if ([name isEqualToString:@"navPoint"]) {
            NSMutableDictionary *d = [NSMutableDictionary dictionary];
            d[@"title"] = @"";
            d[@"href"] = @"";
            d[@"level"] = @(self.tocStack.count);
            [self.tocFlat addObject:d];
            [self.tocStack addObject:d];
        } else if ([name isEqualToString:@"text"]) {
            if (self.tocStack.count) {
                self.currentText = @"";
                self.capturingNavText = YES;
            }
        } else if ([name isEqualToString:@"content"]) {
            if (self.tocStack.count) {
                NSString *src = attributes[@"src"];
                if (src.length) self.tocStack.lastObject[@"href"] = src;
            }
        }
        return;
    }

    if (self.parseMode == IREPUBParseModeNAV) {
        if ([name isEqualToString:@"nav"]) {
            NSString *tipo = attributes[@"epub:type"] ?: attributes[@"type"] ?: @"";
            self.inTOCNav = ([tipo rangeOfString:@"toc"].location != NSNotFound);
            self.navDepth = 0;
        } else if ([name isEqualToString:@"ol"]) {
            if (self.inTOCNav) self.navDepth++;
        } else if ([name isEqualToString:@"a"]) {
            if (self.inTOCNav) {
                NSMutableDictionary *d = [NSMutableDictionary dictionary];
                d[@"title"] = @"";
                d[@"href"] = attributes[@"href"] ?: @"";
                d[@"level"] = @(MAX(0, self.navDepth - 1));
                [self.tocFlat addObject:d];
                self.navCurrent = d;
                self.currentText = @"";
                self.capturingNavText = YES;
            }
        }
        return;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.capturingNavText || self.currentTextKey.length || self.currentMetaProperty.length) {
        self.currentText = [self.currentText stringByAppendingString:string ?: @""];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSString *name = elementName;
    if (qName.length) name = [qName componentsSeparatedByString:@":"].lastObject;
    if (namespaceURI.length && elementName.length) name = elementName;

    if (self.parseMode == IREPUBParseModeOPF) {
        if ([name isEqualToString:@"meta"] && self.currentMetaProperty.length) {
            NSString *valor = [self.currentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (valor.length) [self applyMetaProperty:self.currentMetaProperty value:valor];
            self.currentMetaProperty = nil;
            self.currentText = @"";
        } else if (self.currentTextKey.length && [name isEqualToString:self.currentTextKey]) {
            NSString *valor = [self.currentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([name isEqualToString:@"title"]) self.title = valor;
            else if ([name isEqualToString:@"creator"]) self.author = valor;
            else if ([name isEqualToString:@"language"]) self.language = valor;
            else if ([name isEqualToString:@"description"]) self.bookDescription = valor;
            else if ([name isEqualToString:@"publisher"]) self.publisher = valor;
            self.currentTextKey = nil;
            self.currentText = @"";
        }
        return;
    }

    if (self.parseMode == IREPUBParseModeNCX) {
        if ([name isEqualToString:@"text"] && self.capturingNavText) {
            if (self.tocStack.count) {
                NSString *t = [self.currentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (t.length) self.tocStack.lastObject[@"title"] = t;
            }
            self.capturingNavText = NO;
            self.currentText = @"";
        } else if ([name isEqualToString:@"navPoint"]) {
            if (self.tocStack.count) [self.tocStack removeLastObject];
        }
        return;
    }

    if (self.parseMode == IREPUBParseModeNAV) {
        if ([name isEqualToString:@"a"] && self.navCurrent) {
            NSString *t = [self.currentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (t.length) self.navCurrent[@"title"] = t;
            self.navCurrent = nil;
            self.capturingNavText = NO;
            self.currentText = @"";
        } else if ([name isEqualToString:@"ol"] && self.inTOCNav) {
            self.navDepth = MAX(0, self.navDepth - 1);
        } else if ([name isEqualToString:@"nav"]) {
            self.inTOCNav = NO;
        }
        return;
    }
}

- (void)applyMetaProperty:(NSString *)property value:(NSString *)value {
    if ([property rangeOfString:@"rendition:layout"].location != NSNotFound) {
        if ([value rangeOfString:@"pre-paginated"].location != NSNotFound) self.fixedLayout = YES;
    }
}

@end
