#import "IRMarkdown.h"

@implementation IRMarkdown

+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown
                                            baseFont:(UIFont *)baseFont
                                           textColor:(UIColor *)textColor
                                         accentColor:(UIColor *)accentColor {
    if (!markdown.length) return [[NSAttributedString alloc] initWithString:@""];
    NSMutableAttributedString *salida = [[NSMutableAttributedString alloc] init];
    NSArray *lineas = [markdown componentsSeparatedByString:@"\n"];
    BOOL enCodigo = NO;

    for (NSUInteger i = 0; i < lineas.count; i++) {
        NSString *linea = lineas[i];
        NSString *recortada = [linea stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([recortada hasPrefix:@"```"]) {
            enCodigo = !enCodigo;
            continue;
        }

        if (enCodigo) {
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:baseFont.pointSize * 0.88]
                    ?: [UIFont systemFontOfSize:baseFont.pointSize * 0.88],
                NSForegroundColorAttributeName: textColor,
                NSBackgroundColorAttributeName: [textColor colorWithAlphaComponent:0.06]
            };
            [salida appendAttributedString:[[NSAttributedString alloc] initWithString:[linea stringByAppendingString:@"\n"]
                                                                           attributes:attrs]];
            continue;
        }

        if ([recortada isEqualToString:@"---"] || [recortada isEqualToString:@"***"] ||
            [recortada isEqualToString:@"___"]) {
            NSDictionary *attrs = @{
                NSFontAttributeName: [UIFont systemFontOfSize:baseFont.pointSize * 0.7],
                NSForegroundColorAttributeName: [textColor colorWithAlphaComponent:0.30]
            };
            [salida appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
                                                                           attributes:attrs]];
            continue;
        }

        // Encabezados.
        NSInteger nivel = 0;
        NSString *contenido = linea;
        while (nivel < 6 && contenido.length > nivel && [contenido characterAtIndex:(NSUInteger)nivel] == '#') {
            nivel++;
        }
        if (nivel > 0 && contenido.length > (NSUInteger)nivel &&
            [contenido characterAtIndex:(NSUInteger)nivel] == ' ') {
            contenido = [contenido substringFromIndex:(NSUInteger)nivel + 1];
            CGFloat factor = 1.0 + (7 - nivel) * 0.10;
            UIFont *fuente = [UIFont fontWithName:@"Georgia-Bold" size:baseFont.pointSize * factor]
                             ?: [UIFont boldSystemFontOfSize:baseFont.pointSize * factor];
            NSMutableAttributedString *titulo = [self inlineMarkdown:contenido
                                                               font:fuente
                                                              color:textColor
                                                         accentColor:accentColor];
            [titulo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            [salida appendAttributedString:titulo];
            continue;
        }

        // Citas.
        if ([recortada hasPrefix:@"> "]) {
            NSString *texto = [recortada substringFromIndex:2];
            NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
            p.firstLineHeadIndent = 12;
            p.headIndent = 12;
            UIFont *fuente = [UIFont italicSystemFontOfSize:baseFont.pointSize];
            NSMutableAttributedString *cita = [self inlineMarkdown:texto font:fuente
                                                              color:[textColor colorWithAlphaComponent:0.78]
                                                        accentColor:accentColor];
            [cita addAttribute:NSParagraphStyleAttributeName value:p
                         range:NSMakeRange(0, cita.length)];
            [cita appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            [salida appendAttributedString:cita];
            continue;
        }

        // Listas.
        NSRange rangoLista = NSMakeRange(0, 0);
        BOOL esLista = NO;
        NSString *prefijo = @"";
        if ([recortada hasPrefix:@"- "] || [recortada hasPrefix:@"* "] || [recortada hasPrefix:@"+ "]) {
            esLista = YES;
            prefijo = @"\u2022  ";
            contenido = [recortada substringFromIndex:2];
        } else {
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\.\\s+(.*)$"
                                                                               options:0 error:NULL];
            NSTextCheckingResult *m = [re firstMatchInString:recortada options:0
                                                       range:NSMakeRange(0, recortada.length)];
            if (m) {
                esLista = YES;
                prefijo = [NSString stringWithFormat:@"%@.  ", [recortada substringWithRange:[m rangeAtIndex:1]]];
                contenido = [recortada substringWithRange:[m rangeAtIndex:2]];
            }
        }
        if (esLista) {
            NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
            p.firstLineHeadIndent = 0;
            p.headIndent = baseFont.pointSize * 1.2;
            p.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                                           location:baseFont.pointSize * 1.2 options:@{}]];
            NSMutableAttributedString *item = [[NSMutableAttributedString alloc] initWithString:prefijo
                attributes:@{NSFontAttributeName: baseFont, NSForegroundColorAttributeName: accentColor}];
            [item appendAttributedString:[self inlineMarkdown:contenido font:baseFont
                                                         color:textColor accentColor:accentColor]];
            [item addAttribute:NSParagraphStyleAttributeName value:p range:NSMakeRange(0, item.length)];
            [item appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            [salida appendAttributedString:item];
            continue;
        }

        NSMutableAttributedString *normal = [self inlineMarkdown:linea font:baseFont
                                                           color:textColor accentColor:accentColor];
        [normal appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        [salida appendAttributedString:normal];
    }

    return salida;
}

+ (NSMutableAttributedString *)inlineMarkdown:(NSString *)texto
                                         font:(UIFont *)font
                                        color:(UIColor *)color
                                  accentColor:(UIColor *)accent {
    NSMutableAttributedString *salida = [[NSMutableAttributedString alloc] init];
    if (!texto.length) return salida;
    NSUInteger i = 0;
    NSMutableString *buffer = [NSMutableString string];

    void (^vaciar)(void) = ^{
        if (!buffer.length) return;
        [salida appendAttributedString:[[NSAttributedString alloc] initWithString:buffer
            attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color}]];
        [buffer setString:@""];
    };

    while (i < texto.length) {
        unichar c = [texto characterAtIndex:i];

        // Codigo en linea.
        if (c == '`') {
            NSRange resto = [texto rangeOfString:@"`" options:0
                                           range:NSMakeRange(i + 1, texto.length - i - 1)];
            if (resto.location != NSNotFound) {
                vaciar();
                NSString *codigo = [texto substringWithRange:
                                    NSMakeRange(i + 1, resto.location - i - 1)];
                UIFont *mono = [UIFont fontWithName:@"Menlo" size:font.pointSize * 0.88]
                               ?: [UIFont systemFontOfSize:font.pointSize * 0.88];
                [salida appendAttributedString:[[NSAttributedString alloc] initWithString:codigo
                    attributes:@{NSFontAttributeName: mono, NSForegroundColorAttributeName: color,
                                 NSBackgroundColorAttributeName: [color colorWithAlphaComponent:0.08]}]];
                i = resto.location + 1;
                continue;
            }
        }

        // Negrita.
        if (c == '*' && i + 1 < texto.length && [texto characterAtIndex:i + 1] == '*') {
            NSRange resto = [texto rangeOfString:@"**" options:0
                                           range:NSMakeRange(i + 2, texto.length - i - 2)];
            if (resto.location != NSNotFound) {
                vaciar();
                NSString *negrita = [texto substringWithRange:
                                     NSMakeRange(i + 2, resto.location - i - 2)];
                UIFont *f = [UIFont fontWithName:[NSString stringWithFormat:@"%@-Bold", font.fontName]
                                            size:font.pointSize];
                if (!f) f = [UIFont boldSystemFontOfSize:font.pointSize];
                [salida appendAttributedString:[[NSAttributedString alloc] initWithString:negrita
                    attributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: color}]];
                i = resto.location + 2;
                continue;
            }
        }

        // Cursiva.
        if (c == '*') {
            NSRange resto = [texto rangeOfString:@"*" options:0
                                           range:NSMakeRange(i + 1, texto.length - i - 1)];
            if (resto.location != NSNotFound && resto.location > i + 1) {
                vaciar();
                NSString *cursiva = [texto substringWithRange:
                                     NSMakeRange(i + 1, resto.location - i - 1)];
                UIFont *f = [UIFont italicSystemFontOfSize:font.pointSize];
                [salida appendAttributedString:[[NSAttributedString alloc] initWithString:cursiva
                    attributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: color}]];
                i = resto.location + 1;
                continue;
            }
        }

        // Enlaces [texto](url).
        if (c == '[') {
            NSRange cierre = [texto rangeOfString:@"]" options:0
                                           range:NSMakeRange(i + 1, texto.length - i - 1)];
            if (cierre.location != NSNotFound && cierre.location + 1 < texto.length &&
                [texto characterAtIndex:cierre.location + 1] == '(') {
                NSRange fin = [texto rangeOfString:@")" options:0
                                             range:NSMakeRange(cierre.location + 2,
                                                               texto.length - cierre.location - 2)];
                if (fin.location != NSNotFound) {
                    vaciar();
                    NSString *etiqueta = [texto substringWithRange:
                                          NSMakeRange(i + 1, cierre.location - i - 1)];
                    [salida appendAttributedString:[[NSAttributedString alloc] initWithString:etiqueta
                        attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: accent,
                                     NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)}]];
                    i = fin.location + 1;
                    continue;
                }
            }
        }

        [buffer appendFormat:@"%C", c];
        i++;
    }
    vaciar();
    return salida;
}

@end
