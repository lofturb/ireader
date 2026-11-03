#import "IRIcons.h"

@implementation IRIcons

+ (UIImage *)icon:(IRGlyph)glyph size:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(ctx, true);
    [color setStroke];
    [color setFill];

    CGFloat lw = MAX(1.3, size * 0.072);
    CGFloat s = size;
    CGFloat m = s * 0.18;          // margen
    CGFloat w = s - m * 2;
    UIBezierPath *p = [UIBezierPath bezierPath];
    p.lineWidth = lw;
    p.lineCapStyle = kCGLineCapRound;
    p.lineJoinStyle = kCGLineJoinRound;

    switch (glyph) {
        case IRGlyphLibrary: {
            for (int i = 0; i < 3; i++) {
                CGFloat x = m + i * (w / 3.2);
                [p moveToPoint:CGPointMake(x, s - m)];
                [p addLineToPoint:CGPointMake(x, m + (i == 1 ? s * 0.08 : 0))];
            }
            [p moveToPoint:CGPointMake(m, s - m)];
            [p addLineToPoint:CGPointMake(s - m, s - m)];
            [p stroke];
            break;
        }
        case IRGlyphBook: {
            [p moveToPoint:CGPointMake(m, m + w * 0.18)];
            [p addQuadCurveToPoint:CGPointMake(s / 2, m + w * 0.32)
                         controlPoint:CGPointMake(m + w * 0.25, m)];
            [p addQuadCurveToPoint:CGPointMake(s - m, m + w * 0.18)
                         controlPoint:CGPointMake(s - m - w * 0.25, m)];
            [p addLineToPoint:CGPointMake(s - m, s - m - w * 0.08)];
            [p addQuadCurveToPoint:CGPointMake(s / 2, s - m - w * 0.22)
                         controlPoint:CGPointMake(s - m - w * 0.25, s - m - w * 0.38)];
            [p addQuadCurveToPoint:CGPointMake(m, s - m - w * 0.08)
                         controlPoint:CGPointMake(m + w * 0.25, s - m - w * 0.38)];
            [p closePath];
            [p stroke];
            UIBezierPath *l = [UIBezierPath bezierPath];
            l.lineWidth = lw;
            [l moveToPoint:CGPointMake(s / 2, m + w * 0.32)];
            [l addLineToPoint:CGPointMake(s / 2, s - m - w * 0.22)];
            [l stroke];
            break;
        }
        case IRGlyphBookmark:
        case IRGlyphBookmarkFill: {
            [p moveToPoint:CGPointMake(m + w * 0.12, m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.12, m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.12, s - m)];
            [p addLineToPoint:CGPointMake(s / 2, s - m - w * 0.22)];
            [p addLineToPoint:CGPointMake(m + w * 0.12, s - m)];
            [p closePath];
            if (glyph == IRGlyphBookmarkFill) { [p fill]; } else { [p stroke]; }
            break;
        }
        case IRGlyphSearch:
        case IRGlyphZoomIn:
        case IRGlyphZoomOut: {
            CGFloat r = w * 0.32;
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(m + r, m + r)
                                                             radius:r startAngle:0 endAngle:M_PI * 2
                                                          clockwise:YES];
            c.lineWidth = lw;
            [c stroke];
            [p moveToPoint:CGPointMake(m + r * 1.72, m + r * 1.72)];
            [p addLineToPoint:CGPointMake(s - m, s - m)];
            [p stroke];
            if (glyph != IRGlyphSearch) {
                UIBezierPath *h = [UIBezierPath bezierPath];
                h.lineWidth = lw;
                [h moveToPoint:CGPointMake(m + r * 0.55, m + r)];
                [h addLineToPoint:CGPointMake(m + r * 1.45, m + r)];
                if (glyph == IRGlyphZoomIn) {
                    [h moveToPoint:CGPointMake(m + r, m + r * 0.55)];
                    [h addLineToPoint:CGPointMake(m + r, m + r * 1.45)];
                }
                [h stroke];
            }
            break;
        }
        case IRGlyphGear: {
            CGFloat r = w * 0.26;
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2)
                                                             radius:r startAngle:0 endAngle:M_PI * 2
                                                          clockwise:YES];
            c.lineWidth = lw;
            [c stroke];
            for (int i = 0; i < 8; i++) {
                CGFloat a = i * M_PI / 4;
                UIBezierPath *t = [UIBezierPath bezierPath];
                t.lineWidth = lw;
                [t moveToPoint:CGPointMake(s / 2 + cos(a) * (r + lw), s / 2 + sin(a) * (r + lw))];
                [t addLineToPoint:CGPointMake(s / 2 + cos(a) * (r + w * 0.16), s / 2 + sin(a) * (r + w * 0.16))];
                [t stroke];
            }
            break;
        }
        case IRGlyphFolder: {
            [p moveToPoint:CGPointMake(m, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m + w * 0.34, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m + w * 0.44, m + w * 0.30)];
            [p addLineToPoint:CGPointMake(s - m, m + w * 0.30)];
            [p addLineToPoint:CGPointMake(s - m, s - m)];
            [p addLineToPoint:CGPointMake(m, s - m)];
            [p closePath];
            [p stroke];
            break;
        }
        case IRGlyphWifi: {
            for (int i = 0; i < 3; i++) {
                CGFloat r = w * (0.24 + i * 0.19);
                UIBezierPath *a = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s - m)
                                                                 radius:r startAngle:M_PI * 1.22
                                                               endAngle:M_PI * 1.78 clockwise:YES];
                a.lineWidth = lw;
                [a stroke];
            }
            UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s - m)
                                                               radius:lw * 1.1 startAngle:0
                                                            endAngle:M_PI * 2 clockwise:YES];
            [dot fill];
            break;
        }
        case IRGlyphChevronLeft:
        case IRGlyphChevronRight:
        case IRGlyphChevronUp:
        case IRGlyphChevronDown: {
            CGPoint a, b, c;
            if (glyph == IRGlyphChevronLeft) {
                a = CGPointMake(m + w * 0.62, m); b = CGPointMake(m + w * 0.28, s / 2); c = CGPointMake(m + w * 0.62, s - m);
            } else if (glyph == IRGlyphChevronRight) {
                a = CGPointMake(m + w * 0.38, m); b = CGPointMake(m + w * 0.72, s / 2); c = CGPointMake(m + w * 0.38, s - m);
            } else if (glyph == IRGlyphChevronUp) {
                a = CGPointMake(m, m + w * 0.62); b = CGPointMake(s / 2, m + w * 0.28); c = CGPointMake(s - m, m + w * 0.62);
            } else {
                a = CGPointMake(m, m + w * 0.38); b = CGPointMake(s / 2, m + w * 0.72); c = CGPointMake(s - m, m + w * 0.38);
            }
            [p moveToPoint:a]; [p addLineToPoint:b]; [p addLineToPoint:c]; [p stroke];
            break;
        }
        case IRGlyphGrid: {
            CGFloat g = w * 0.12;
            CGFloat d = (w - g) / 2;
            for (int i = 0; i < 4; i++) {
                CGRect r = CGRectMake(m + (i % 2) * (d + g), m + (i / 2) * (d + g), d, d);
                UIBezierPath *q = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:d * 0.18];
                q.lineWidth = lw;
                [q stroke];
            }
            break;
        }
        case IRGlyphList: {
            for (int i = 0; i < 3; i++) {
                CGFloat y = m + i * (w / 2.4);
                [p moveToPoint:CGPointMake(m + w * 0.18, y)];
                [p addLineToPoint:CGPointMake(s - m, y)];
                UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:CGPointMake(m, y) radius:lw * 0.8 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
                [dot fill];
            }
            [p stroke];
            break;
        }
        case IRGlyphSun:
        case IRGlyphBrightness: {
            CGFloat r = w * 0.22;
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:r startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            c.lineWidth = lw;
            [c stroke];
            if (glyph == IRGlyphBrightness) {
                UIBezierPath *half = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:r startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:YES];
                [half addLineToPoint:CGPointMake(s / 2, s / 2)];
                [half fill];
            }
            for (int i = 0; i < 8; i++) {
                CGFloat a = i * M_PI / 4;
                UIBezierPath *ray = [UIBezierPath bezierPath];
                ray.lineWidth = lw;
                [ray moveToPoint:CGPointMake(s / 2 + cos(a) * (r + lw * 1.4), s / 2 + sin(a) * (r + lw * 1.4))];
                [ray addLineToPoint:CGPointMake(s / 2 + cos(a) * (r + w * 0.16), s / 2 + sin(a) * (r + w * 0.16))];
                [ray stroke];
            }
            break;
        }
        case IRGlyphMoon: {
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:w * 0.36 startAngle:M_PI * 0.35 endAngle:M_PI * 1.65 clockwise:YES];
            c.lineWidth = lw;
            [c stroke];
            UIBezierPath *c2 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2 + w * 0.16, s / 2 - w * 0.10) radius:w * 0.31 startAngle:M_PI * 0.25 endAngle:M_PI * 1.55 clockwise:YES];
            c2.lineWidth = lw;
            [c2 stroke];
            break;
        }
        case IRGlyphTextSize:
        case IRGlyphFont: {
            UIFont *f = [UIFont boldSystemFontOfSize:s * 0.42];
            [color setFill];
            [@"A" drawAtPoint:CGPointMake(m, m + w * 0.08) withAttributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:color}];
            UIFont *f2 = [UIFont boldSystemFontOfSize:s * 0.28];
            [@"a" drawAtPoint:CGPointMake(s * 0.55, s * 0.45) withAttributes:@{NSFontAttributeName:f2, NSForegroundColorAttributeName:color}];
            break;
        }
        case IRGlyphTOC: {
            for (int i = 0; i < 4; i++) {
                CGFloat y = m + i * (w / 3);
                CGFloat x = m + (i % 2) * w * 0.16;
                [p moveToPoint:CGPointMake(x, y)];
                [p addLineToPoint:CGPointMake(s - m - (i % 3 == 0 ? 0 : w * 0.14), y)];
            }
            [p stroke];
            break;
        }
        case IRGlyphNote: {
            [p moveToPoint:CGPointMake(m, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.18, s - m)];
            [p addLineToPoint:CGPointMake(s - m, s - m - w * 0.18)];
            [p addLineToPoint:CGPointMake(s - m, m + w * 0.18)];
            [p closePath];
            [p moveToPoint:CGPointMake(m + w * 0.18, s - m - w * 0.18)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.18, m + w * 0.18)];
            [p stroke];
            break;
        }
        case IRGlyphTrash: {
            [p moveToPoint:CGPointMake(m + w * 0.16, m + w * 0.24)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.16, m + w * 0.24)];
            [p moveToPoint:CGPointMake(m + w * 0.28, m + w * 0.24)];
            [p addLineToPoint:CGPointMake(m + w * 0.34, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.34, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.28, m + w * 0.24)];
            [p moveToPoint:CGPointMake(s / 2 - w * 0.12, m + w * 0.24)];
            [p addLineToPoint:CGPointMake(s / 2 - w * 0.08, m + w * 0.08)];
            [p addLineToPoint:CGPointMake(s / 2 + w * 0.08, m + w * 0.08)];
            [p addLineToPoint:CGPointMake(s / 2 + w * 0.12, m + w * 0.24)];
            [p stroke];
            break;
        }
        case IRGlyphInfo: {
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:w * 0.40 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            c.lineWidth = lw;
            [c stroke];
            UIFont *f = [UIFont boldSystemFontOfSize:s * 0.42];
            [@"i" drawAtPoint:CGPointMake(s / 2 - s * 0.045, s * 0.25) withAttributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:color}];
            break;
        }
        case IRGlyphClose: {
            [p moveToPoint:CGPointMake(m + w * 0.14, m + w * 0.14)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.14, s - m - w * 0.14)];
            [p moveToPoint:CGPointMake(s - m - w * 0.14, m + w * 0.14)];
            [p addLineToPoint:CGPointMake(m + w * 0.14, s - m - w * 0.14)];
            [p stroke];
            break;
        }
        case IRGlyphPlus: {
            [p moveToPoint:CGPointMake(s / 2, m + w * 0.12)];
            [p addLineToPoint:CGPointMake(s / 2, s - m - w * 0.12)];
            [p moveToPoint:CGPointMake(m + w * 0.12, s / 2)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.12, s / 2)];
            [p stroke];
            break;
        }
        case IRGlyphCheck: {
            [p moveToPoint:CGPointMake(m + w * 0.12, s / 2)];
            [p addLineToPoint:CGPointMake(s / 2 - w * 0.04, s - m - w * 0.16)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.10, m + w * 0.18)];
            [p stroke];
            break;
        }
        case IRGlyphArrowLeft:
        case IRGlyphBack: {
            [p moveToPoint:CGPointMake(s - m, s / 2)];
            [p addLineToPoint:CGPointMake(m + w * 0.08, s / 2)];
            [p moveToPoint:CGPointMake(m + w * 0.08, s / 2)];
            [p addLineToPoint:CGPointMake(m + w * 0.42, m + w * 0.16)];
            [p moveToPoint:CGPointMake(m + w * 0.08, s / 2)];
            [p addLineToPoint:CGPointMake(m + w * 0.42, s - m - w * 0.16)];
            [p stroke];
            break;
        }
        case IRGlyphArrowRight: {
            [p moveToPoint:CGPointMake(m, s / 2)];
            [p addLineToPoint:CGPointMake(s - m, s / 2)];
            [p moveToPoint:CGPointMake(s - m, s / 2)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.34, m + w * 0.16)];
            [p moveToPoint:CGPointMake(s - m, s / 2)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.34, s - m - w * 0.16)];
            [p stroke];
            break;
        }
        case IRGlyphArrowUp: {
            [p moveToPoint:CGPointMake(s / 2, s - m)];
            [p addLineToPoint:CGPointMake(s / 2, m)];
            [p moveToPoint:CGPointMake(s / 2, m)];
            [p addLineToPoint:CGPointMake(m + w * 0.16, m + w * 0.34)];
            [p moveToPoint:CGPointMake(s / 2, m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.16, m + w * 0.34)];
            [p stroke];
            break;
        }
        case IRGlyphArrowDown: {
            [p moveToPoint:CGPointMake(s / 2, m)];
            [p addLineToPoint:CGPointMake(s / 2, s - m)];
            [p moveToPoint:CGPointMake(s / 2, s - m)];
            [p addLineToPoint:CGPointMake(m + w * 0.16, s - m - w * 0.34)];
            [p moveToPoint:CGPointMake(s / 2, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.16, s - m - w * 0.34)];
            [p stroke];
            break;
        }
        case IRGlyphPlay: {
            UIBezierPath *t = [UIBezierPath bezierPath];
            [t moveToPoint:CGPointMake(m + w * 0.22, m + w * 0.10)];
            [t addLineToPoint:CGPointMake(s - m - w * 0.10, s / 2)];
            [t addLineToPoint:CGPointMake(m + w * 0.22, s - m - w * 0.10)];
            [t closePath];
            [t fill];
            break;
        }
        case IRGlyphPause: {
            [p moveToPoint:CGPointMake(m + w * 0.30, m + w * 0.10)];
            [p addLineToPoint:CGPointMake(m + w * 0.30, s - m - w * 0.10)];
            [p moveToPoint:CGPointMake(s - m - w * 0.30, m + w * 0.10)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.30, s - m - w * 0.10)];
            p.lineWidth = lw * 2.2;
            [p stroke];
            break;
        }
        case IRGlyphRefresh: {
            UIBezierPath *a = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:w * 0.34 startAngle:-M_PI * 0.35 endAngle:M_PI * 1.25 clockwise:YES];
            a.lineWidth = lw;
            [a stroke];
            [p moveToPoint:CGPointMake(s / 2 + w * 0.20, m + w * 0.06)];
            [p addLineToPoint:CGPointMake(s / 2 + w * 0.38, m + w * 0.20)];
            [p addLineToPoint:CGPointMake(s / 2 + w * 0.20, m + w * 0.34)];
            [p stroke];
            break;
        }
        case IRGlyphFile: {
            [p moveToPoint:CGPointMake(m + w * 0.14, m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.28, m)];
            [p addLineToPoint:CGPointMake(s - m, m + w * 0.28)];
            [p addLineToPoint:CGPointMake(s - m, s - m)];
            [p addLineToPoint:CGPointMake(m + w * 0.14, s - m)];
            [p closePath];
            [p moveToPoint:CGPointMake(s - m - w * 0.28, m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.28, m + w * 0.28)];
            [p addLineToPoint:CGPointMake(s - m, m + w * 0.28)];
            [p stroke];
            break;
        }
        case IRGlyphImage: {
            UIBezierPath *r = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m, m + w * 0.10, w, w * 0.80) cornerRadius:w * 0.10];
            r.lineWidth = lw;
            [r stroke];
            [p moveToPoint:CGPointMake(m + w * 0.08, s - m - w * 0.18)];
            [p addLineToPoint:CGPointMake(m + w * 0.36, m + w * 0.36)];
            [p addLineToPoint:CGPointMake(m + w * 0.60, s - m - w * 0.30)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.08, m + w * 0.42)];
            [p stroke];
            UIBezierPath *sun = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s - m - w * 0.22, m + w * 0.30) radius:w * 0.07 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            [sun fill];
            break;
        }
        case IRGlyphLock: {
            UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m + w * 0.12, s * 0.45, w * 0.76, s * 0.36) cornerRadius:w * 0.10];
            body.lineWidth = lw;
            [body stroke];
            UIBezierPath *shackle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s * 0.45) radius:w * 0.22 startAngle:M_PI endAngle:0 clockwise:YES];
            shackle.lineWidth = lw;
            [shackle stroke];
            break;
        }
        case IRGlyphSort: {
            [p moveToPoint:CGPointMake(m + w * 0.12, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m + w * 0.12, s - m - w * 0.10)];
            [p moveToPoint:CGPointMake(m + w * 0.12, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m - w * 0.02 + w * 0.12, m + w * 0.36)];
            [p moveToPoint:CGPointMake(m + w * 0.12, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(m + w * 0.26, m + w * 0.36)];
            [p moveToPoint:CGPointMake(s - m - w * 0.42, m + w * 0.18)];
            [p addLineToPoint:CGPointMake(s - m, m + w * 0.18)];
            [p moveToPoint:CGPointMake(s - m - w * 0.42, s / 2)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.10, s / 2)];
            [p moveToPoint:CGPointMake(s - m - w * 0.42, s - m - w * 0.18)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.22, s - m - w * 0.18)];
            [p stroke];
            break;
        }
        case IRGlyphHome: {
            [p moveToPoint:CGPointMake(m, s / 2)];
            [p addLineToPoint:CGPointMake(s / 2, m + w * 0.10)];
            [p addLineToPoint:CGPointMake(s - m, s / 2)];
            [p moveToPoint:CGPointMake(m + w * 0.14, s / 2 - w * 0.04)];
            [p addLineToPoint:CGPointMake(m + w * 0.14, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.14, s - m)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.14, s / 2 - w * 0.04)];
            [p stroke];
            break;
        }
        case IRGlyphStar:
        case IRGlyphStarFill: {
            CGPoint pts[10];
            CGFloat cx = s / 2, cy = s / 2 + w * 0.04, R = w * 0.44, r = w * 0.18;
            for (int i = 0; i < 10; i++) {
                CGFloat a = -M_PI_2 + i * M_PI / 5;
                CGFloat rad = (i % 2 == 0) ? R : r;
                pts[i] = CGPointMake(cx + cos(a) * rad, cy + sin(a) * rad);
            }
            [p moveToPoint:pts[0]];
            for (int i = 1; i < 10; i++) [p addLineToPoint:pts[i]];
            [p closePath];
            if (glyph == IRGlyphStarFill) [p fill]; else [p stroke];
            break;
        }
        case IRGlyphClock: {
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:w * 0.40 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            c.lineWidth = lw; [c stroke];
            [p moveToPoint:CGPointMake(s / 2, s / 2)];
            [p addLineToPoint:CGPointMake(s / 2, s * 0.30)];
            [p moveToPoint:CGPointMake(s / 2, s / 2)];
            [p addLineToPoint:CGPointMake(s * 0.66, s * 0.58)];
            [p stroke];
            break;
        }
        case IRGlyphGlobe: {
            UIBezierPath *c = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, s / 2) radius:w * 0.40 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
            c.lineWidth = lw; [c stroke];
            [p moveToPoint:CGPointMake(m + w * 0.06, s / 2)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.06, s / 2)];
            [p moveToPoint:CGPointMake(s / 2, m + w * 0.06)];
            [p addQuadCurveToPoint:CGPointMake(s / 2, s - m - w * 0.06) controlPoint:CGPointMake(s * 0.20, s / 2)];
            [p moveToPoint:CGPointMake(s / 2, m + w * 0.06)];
            [p addQuadCurveToPoint:CGPointMake(s / 2, s - m - w * 0.06) controlPoint:CGPointMake(s * 0.80, s / 2)];
            [p stroke];
            break;
        }
        case IRGlyphPage: {
            UIBezierPath *r = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m + w * 0.14, m, w * 0.72, s - m * 2) cornerRadius:w * 0.06];
            r.lineWidth = lw; [r stroke];
            for (int i = 0; i < 4; i++) {
                CGFloat y = m + w * 0.26 + i * w * 0.14;
                [p moveToPoint:CGPointMake(m + w * 0.28, y)];
                [p addLineToPoint:CGPointMake(s - m - w * 0.28, y)];
            }
            [p stroke];
            break;
        }
        case IRGlyphTwoPage: {
            UIBezierPath *a = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m, m + w * 0.10, w * 0.44, w * 0.80) cornerRadius:w * 0.06];
            a.lineWidth = lw; [a stroke];
            UIBezierPath *b = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m + w * 0.52, m + w * 0.10, w * 0.44, w * 0.80) cornerRadius:w * 0.06];
            b.lineWidth = lw; [b stroke];
            break;
        }
        case IRGlyphMore: {
            for (int i = 0; i < 3; i++) {
                UIBezierPath *d = [UIBezierPath bezierPathWithArcCenter:CGPointMake(s / 2, m + w * 0.14 + i * w * 0.32) radius:lw * 0.9 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
                [d fill];
            }
            break;
        }
        case IRGlyphDownload:
        case IRGlyphUpload: {
            BOOL up = (glyph == IRGlyphUpload);
            [p moveToPoint:CGPointMake(s / 2, up ? s - m - w * 0.10 : m + w * 0.10)];
            [p addLineToPoint:CGPointMake(s / 2, up ? m + w * 0.18 : s - m - w * 0.18)];
            CGFloat tipY = up ? m + w * 0.18 : s - m - w * 0.18;
            [p moveToPoint:CGPointMake(s / 2, tipY)];
            [p addLineToPoint:CGPointMake(s / 2 - w * 0.16, tipY + (up ? w * 0.16 : -w * 0.16))];
            [p moveToPoint:CGPointMake(s / 2, tipY)];
            [p addLineToPoint:CGPointMake(s / 2 + w * 0.16, tipY + (up ? w * 0.16 : -w * 0.16))];
            [p moveToPoint:CGPointMake(m + w * 0.10, s - m - w * 0.02)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.10, s - m - w * 0.02)];
            [p stroke];
            break;
        }
        case IRGlyphHex: {
            UIFont *f = [UIFont fontWithName:@"Menlo-Bold" size:s * 0.30] ?: [UIFont boldSystemFontOfSize:s * 0.30];
            [@"0x" drawAtPoint:CGPointMake(m, s * 0.35) withAttributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:color}];
            break;
        }
        case IRGlyphOriginal: {
            UIBezierPath *r = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m, m, w, w) cornerRadius:w * 0.12];
            r.lineWidth = lw; [r stroke];
            [p moveToPoint:CGPointMake(m + w * 0.22, s - m - w * 0.22)];
            [p addLineToPoint:CGPointMake(s - m - w * 0.22, m + w * 0.22)];
            [p moveToPoint:CGPointMake(m + w * 0.22, m + w * 0.22)];
            [p addLineToPoint:CGPointMake(m + w * 0.44, m + w * 0.22)];
            [p moveToPoint:CGPointMake(m + w * 0.22, m + w * 0.22)];
            [p addLineToPoint:CGPointMake(m + w * 0.22, m + w * 0.44)];
            [p stroke];
            break;
        }
    }

    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imagen;
}

@end
