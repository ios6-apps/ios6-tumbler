#import "TBStyle.h"

UIColor *TBRGB(int r, int g, int b) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1]; }
UIFont *TBFont(NSString *name, CGFloat size) { return [UIFont fontWithName:name size:size] ?: [UIFont boldSystemFontOfSize:size]; }

static void comps(UIColor *c, CGFloat *o) {
    if (![c getRed:o green:o + 1 blue:o + 2 alpha:o + 3]) { CGFloat w, a; [c getWhite:&w alpha:&a]; o[0] = o[1] = o[2] = w; o[3] = a; }
}

void TBFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom) {
    CGFloat k[8];
    comps(top, k); comps(bottom, k + 4);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, k, NULL, 2);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}

static void fillGradientH(CGContextRef c, CGRect r, UIColor *left, UIColor *right) {
    CGFloat k[8];
    comps(left, k); comps(right, k + 4);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, k, NULL, 2);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(CGRectGetMinX(r), 0), CGPointMake(CGRectGetMaxX(r), 0), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}

void TBRoundRectPath(CGContextRef c, CGRect r, CGFloat rad) {
    CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
    CGContextMoveToPoint(c, x0 + rad, y0);
    CGContextAddArcToPoint(c, x1, y0, x1, y1, rad);
    CGContextAddArcToPoint(c, x1, y1, x0, y1, rad);
    CGContextAddArcToPoint(c, x0, y1, x0, y0, rad);
    CGContextAddArcToPoint(c, x0, y0, x1, y0, rad);
    CGContextClosePath(c);
}

void TBDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat dy, NSTextAlignment align) {
    if (!s.length) return;
    NSLineBreakMode mode = r.size.height < font.lineHeight * 1.5 ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping;
    if (shadow) { [shadow set]; [s drawInRect:CGRectOffset(r, 0, dy) withFont:font lineBreakMode:mode alignment:align]; }
    [color set];
    [s drawInRect:r withFont:font lineBreakMode:mode alignment:align];
}

UIImage *TBLeatherImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const int N = 96;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(N, N), YES, 0);
        CGContextRef c = UIGraphicsGetCurrentContext();
        [TBRGB(54, 30, 25) setFill]; CGContextFillRect(c, CGRectMake(0, 0, N, N));
        srand(11);
        /* pebbled grain: small dark dimples with a lighter rim on the lit side */
        for (int i = 0; i < 520; i++) {
            CGFloat x = rand() % N, y = rand() % N, d = 2 + rand() % 3;
            for (int ox = -N; ox <= N; ox += N) for (int oy = -N; oy <= N; oy += N) {
                if (x + ox < -6 || x + ox > N + 6 || y + oy < -6 || y + oy > N + 6) continue;
                [[UIColor colorWithWhite:0 alpha:0.20] setFill];
                CGContextFillEllipseInRect(c, CGRectMake(x + ox, y + oy, d, d));
                [[UIColor colorWithRed:1 green:0.75 blue:0.6 alpha:0.10] setFill];
                CGContextFillEllipseInRect(c, CGRectMake(x + ox - 0.6, y + oy - 0.8, d, d * 0.5));
            }
        }
        for (int i = 0; i < 260; i++) {   /* fine speckle */
            [[UIColor colorWithWhite:rand() % 2 alpha:0.06] set];
            CGContextFillRect(c, CGRectMake(rand() % N, rand() % N, 1, 1));
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

static UIImage *brushTile(BOOL dark) {
    static UIImage *tiles[2];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (int t = 0; t < 2; t++) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(128, 64), NO, 0);
            CGContextRef c = UIGraphicsGetCurrentContext();
            srand(31 + t);
            for (int i = 0; i < 150; i++) {
                CGFloat y = rand() % 64, x = rand() % 128, w = 20 + rand() % 90;
                [[UIColor colorWithWhite:rand() % 2 alpha:(t ? 0.07 : 0.06) + (rand() % 5) / 100.0] set];
                CGContextFillRect(c, CGRectMake(x, y, w, 1));
                if (x + w > 128) CGContextFillRect(c, CGRectMake(x - 128, y, w, 1));
            }
            tiles[t] = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    });
    return tiles[dark ? 1 : 0];
}

void TBBrushedSteel(CGContextRef c, CGRect r, BOOL dark) {
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    if (dark) TBFillGradient(c, r, TBRGB(112, 118, 128), TBRGB(52, 56, 64));
    else TBFillGradient(c, r, TBRGB(222, 226, 232), TBRGB(150, 156, 166));
    /* a soft vertical sheen, the way light rakes across a brushed panel */
    CGFloat third = r.size.width / 3;
    fillGradientH(c, CGRectMake(r.origin.x, r.origin.y, third, r.size.height), [UIColor colorWithWhite:1 alpha:0], [UIColor colorWithWhite:1 alpha:dark ? 0.10 : 0.30]);
    fillGradientH(c, CGRectMake(r.origin.x + third, r.origin.y, third, r.size.height), [UIColor colorWithWhite:1 alpha:dark ? 0.10 : 0.30], [UIColor colorWithWhite:1 alpha:0]);
    UIImage *tile = brushTile(dark);
    CGContextClipToRect(c, r);
    CGContextTranslateCTM(c, 0, r.origin.y + r.size.height);
    CGContextScaleCTM(c, 1, -1);
    CGContextDrawTiledImage(c, CGRectMake(r.origin.x, 0, tile.size.width, tile.size.height), tile.CGImage);
    CGContextRestoreGState(c);
}

void TBPlate(CGContextRef c, CGRect r, CGFloat rad) {
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 3), 6, [UIColor colorWithWhite:0 alpha:0.75].CGColor);
    TBRoundRectPath(c, r, rad); [TBRGB(20, 20, 22) setFill]; CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    TBRoundRectPath(c, r, rad); CGContextClip(c);
    TBBrushedSteel(c, r, YES);
    [[UIColor colorWithWhite:1 alpha:0.55] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1));
    TBFillGradient(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 8, r.size.width, 8), [UIColor colorWithWhite:0 alpha:0], [UIColor colorWithWhite:0 alpha:0.28]);
    CGContextRestoreGState(c);
    TBRoundRectPath(c, CGRectInset(r, 0.5, 0.5), rad - 0.5);
    [TBRGB(14, 15, 18) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    TBRoundRectPath(c, CGRectInset(r, 1.5, 1.5), rad - 1.5);
    [[UIColor colorWithWhite:1 alpha:0.12] set]; CGContextStrokePath(c);
}

void TBScrew(CGContextRef c, CGPoint p, CGFloat rad, CGFloat angle) {
    CGRect r = CGRectMake(p.x - rad, p.y - rad, rad * 2, rad * 2);
    CGContextSaveGState(c);
    [[UIColor colorWithWhite:1 alpha:0.35] setFill];
    CGContextFillEllipseInRect(c, CGRectOffset(r, 0, 0.8));
    CGContextAddEllipseInRect(c, r); CGContextClip(c);
    TBFillGradient(c, r, TBRGB(210, 214, 220), TBRGB(78, 82, 90));
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0 alpha:0.7] setStroke];
    CGContextSetLineWidth(c, 0.7);
    CGContextStrokeEllipseInRect(c, CGRectInset(r, 0.3, 0.3));
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, p.x, p.y); CGContextRotateCTM(c, angle);
    [TBRGB(36, 38, 44) setStroke];
    CGContextSetLineWidth(c, MAX(0.8, rad * 0.28));
    CGContextMoveToPoint(c, -rad * 0.62, 0); CGContextAddLineToPoint(c, rad * 0.62, 0);
    CGContextMoveToPoint(c, 0, -rad * 0.62); CGContextAddLineToPoint(c, 0, rad * 0.62);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
}

void TBDymo(CGContextRef c, CGRect r, NSString *text) {
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 1.5, [UIColor colorWithWhite:0 alpha:0.7].CGColor);
    TBRoundRectPath(c, r, 3); [TBRGB(18, 20, 28) setFill]; CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    TBRoundRectPath(c, r, 3); CGContextClip(c);
    TBFillGradient(c, r, TBRGB(46, 52, 70), TBRGB(16, 18, 26));
    /* the tape's raised edges */
    [[UIColor colorWithWhite:1 alpha:0.28] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y + 1.5, r.size.width, 1));
    [[UIColor colorWithWhite:0 alpha:0.55] set]; CGContextFillRect(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 2.5, r.size.width, 1));
    TBFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height / 2), [UIColor colorWithWhite:1 alpha:0.14], [UIColor colorWithWhite:1 alpha:0.02]);
    CGContextRestoreGState(c);
    TBRoundRectPath(c, CGRectInset(r, 0.5, 0.5), 3); [TBRGB(0, 0, 4) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    UIFont *f = TBFont(@"HelveticaNeue-Bold", 12);
    CGSize sz = [text sizeWithFont:f];
    CGRect tr = CGRectMake(r.origin.x + 7, r.origin.y + (r.size.height - sz.height) / 2 - 0.5, r.size.width - 14, sz.height);
    TBDrawText([text uppercaseString], tr, f, [UIColor colorWithWhite:0.97 alpha:1], [UIColor colorWithWhite:0 alpha:0.9], 1, NSTextAlignmentLeft);
}

void TBLCDPanel(CGContextRef c, CGRect r) {
    CGContextSaveGState(c);
    [[UIColor colorWithWhite:1 alpha:0.30] setFill];
    TBRoundRectPath(c, CGRectOffset(r, 0, 1), 5); CGContextFillPath(c);
    TBRoundRectPath(c, r, 5); CGContextClip(c);
    TBFillGradient(c, r, TBRGB(4, 4, 3), TBRGB(26, 20, 10));
    /* inner shadow at the top where the bezel overhangs the glass */
    TBFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 8), [UIColor colorWithWhite:0 alpha:0.85], [UIColor colorWithWhite:0 alpha:0]);
    CGContextRestoreGState(c);
    TBRoundRectPath(c, CGRectInset(r, 0.5, 0.5), 5); [TBRGB(0, 0, 0) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}

/* seven-segment geometry: segments a..g as hexagons in a unit box 0..1 (w) x 0..2 (h) */
static void segPath(CGContextRef c, int s, CGFloat x, CGFloat y, CGFloat w, CGFloat h, CGFloat t) {
    CGFloat g = t * 0.12, hw = t / 2;
    CGPoint pts[6];
    CGFloat midY = y + h / 2;
    switch (s) {
        case 0: case 3: case 6: {  /* horizontal: a (top), d (bottom), g (middle) */
            CGFloat cy = s == 0 ? y + hw : s == 3 ? y + h - hw : midY;
            pts[0] = CGPointMake(x + hw + g, cy); pts[1] = CGPointMake(x + hw + g + hw, cy - hw);
            pts[2] = CGPointMake(x + w - hw - g - hw, cy - hw); pts[3] = CGPointMake(x + w - hw - g, cy);
            pts[4] = CGPointMake(x + w - hw - g - hw, cy + hw); pts[5] = CGPointMake(x + hw + g + hw, cy + hw);
            break; }
        default: {  /* vertical: b, c right; e, f left */
            CGFloat cx = (s == 1 || s == 2) ? x + w - hw : x + hw;
            CGFloat y0 = (s == 1 || s == 5) ? y + hw + g : midY + g, y1 = (s == 1 || s == 5) ? midY - g : y + h - hw - g;
            pts[0] = CGPointMake(cx, y0); pts[1] = CGPointMake(cx + hw, y0 + hw);
            pts[2] = CGPointMake(cx + hw, y1 - hw); pts[3] = CGPointMake(cx, y1);
            pts[4] = CGPointMake(cx - hw, y1 - hw); pts[5] = CGPointMake(cx - hw, y0 + hw);
            break; }
    }
    CGContextMoveToPoint(c, pts[0].x, pts[0].y);
    for (int i = 1; i < 6; i++) CGContextAddLineToPoint(c, pts[i].x, pts[i].y);
    CGContextClosePath(c);
}

void TBDrawSegments(CGContextRef c, CGRect r, NSString *digits, UIColor *lit, BOOL ghost) {
    static const uint8_t mask[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
    NSUInteger n = digits.length;
    if (!n) return;
    /* gaps (spaces) are narrower than digits */
    CGFloat units = 0;
    for (NSUInteger i = 0; i < n; i++) units += [digits characterAtIndex:i] == ' ' ? 0.55 : 1.0;
    CGFloat spacing = 0.22;
    CGFloat dw = r.size.width / (units + spacing * (n - 1));
    dw = MIN(dw, r.size.height * 0.62);
    CGFloat total = dw * units + dw * spacing * (n - 1);
    CGFloat x = r.origin.x + (r.size.width - total) / 2, h = r.size.height, t = dw * 0.2;
    CGFloat slant = 0.10;
    CGContextSaveGState(c);
    CGFloat lc[4]; comps(lit, lc);
    for (NSUInteger i = 0; i < n; i++) {
        unichar ch = [digits characterAtIndex:i];
        if (ch == ' ') { x += dw * (0.55 + spacing); continue; }
        int m = (ch >= '0' && ch <= '9') ? mask[ch - '0'] : 0;
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, x + h * slant, r.origin.y);   /* italic lean, like old LCD calculators */
        CGContextConcatCTM(c, CGAffineTransformMake(1, 0, -slant, 1, 0, 0));
        for (int s = 0; s < 7; s++) {
            BOOL on = (m >> s) & 1;
            if (!on && !ghost) continue;
            CGContextSaveGState(c);
            if (on) {
                CGContextSetShadowWithColor(c, CGSizeZero, 6, [UIColor colorWithRed:lc[0] green:lc[1] blue:lc[2] alpha:0.9].CGColor);
                [lit setFill];
            } else [[UIColor colorWithRed:lc[0] green:lc[1] blue:lc[2] alpha:0.07] setFill];
            segPath(c, s, 0, 0, dw, h, t);
            CGContextFillPath(c);
            CGContextRestoreGState(c);
            if (on) {   /* hot core */
                [[UIColor colorWithRed:1 green:0.93 blue:0.7 alpha:0.5] setFill];
                segPath(c, s, dw * 0.04, h * 0.02, dw * 0.92, h * 0.96, t * 0.55);
                CGContextFillPath(c);
            }
        }
        CGContextRestoreGState(c);
        x += dw * (1 + spacing);
    }
    CGContextRestoreGState(c);
}

void TBGlassButton(CGContextRef c, CGRect r, CGFloat rad, int tone, BOOL pressed) {
    UIColor *t0, *t1, *b0, *b1, *edge;
    if (tone == 1) { t0 = TBRGB(240, 206, 120); t1 = TBRGB(204, 158, 66); b0 = TBRGB(170, 122, 40); b1 = TBRGB(204, 160, 74); edge = TBRGB(70, 44, 8); }
    else if (tone == 2) { t0 = TBRGB(226, 96, 84); t1 = TBRGB(180, 44, 36); b0 = TBRGB(138, 20, 16); b1 = TBRGB(176, 52, 40); edge = TBRGB(60, 6, 4); }
    else { t0 = TBRGB(142, 150, 164); t1 = TBRGB(96, 104, 118); b0 = TBRGB(60, 66, 78); b1 = TBRGB(84, 92, 106); edge = TBRGB(16, 18, 24); }
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1 alpha:0.35].CGColor);
    TBRoundRectPath(c, r, rad); [edge setFill]; CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGRect in = CGRectInset(r, 0.5, 0.5);
    TBRoundRectPath(c, in, rad - 0.5); CGContextClip(c);
    CGFloat h = in.size.height / 2;
    TBFillGradient(c, CGRectMake(in.origin.x, in.origin.y, in.size.width, h), pressed ? t1 : t0, pressed ? b0 : t1);
    TBFillGradient(c, CGRectMake(in.origin.x, in.origin.y + h, in.size.width, in.size.height - h), pressed ? b0 : b0, pressed ? t1 : b1);
    if (!pressed) {
        TBFillGradient(c, CGRectMake(in.origin.x, in.origin.y, in.size.width, h), [UIColor colorWithWhite:1 alpha:0.42], [UIColor colorWithWhite:1 alpha:0.06]);
        [[UIColor colorWithWhite:1 alpha:0.55] set]; CGContextFillRect(c, CGRectMake(in.origin.x, in.origin.y, in.size.width, 1));
    } else {
        TBFillGradient(c, CGRectMake(in.origin.x, in.origin.y, in.size.width, 6), [UIColor colorWithWhite:0 alpha:0.35], [UIColor colorWithWhite:0 alpha:0]);
    }
    CGContextRestoreGState(c);
}

void TBBarBackground(CGContextRef c, CGRect r) {
    TBBrushedSteel(c, r, NO);
    [[UIColor colorWithWhite:1 alpha:0.85] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1));
    TBFillGradient(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 6, r.size.width, 5), [UIColor colorWithWhite:0 alpha:0], [UIColor colorWithWhite:0 alpha:0.18]);
    [TBRGB(44, 46, 52) set]; CGContextFillRect(c, CGRectMake(r.origin.x, CGRectGetMaxY(r) - 1, r.size.width, 1));
}

void TBFooterBackground(CGContextRef c, CGRect r) {
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    TBBrushedSteel(c, r, YES);
    TBFillGradient(c, r, [UIColor colorWithWhite:0 alpha:0.25], [UIColor colorWithWhite:0 alpha:0.62]);
    [[UIColor colorWithWhite:1 alpha:0.5] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1));
    [[UIColor colorWithWhite:0 alpha:0.7] set]; CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y + 1, r.size.width, 1));
    CGContextRestoreGState(c);
}

static void keyShape(CGContextRef c, CGRect r) {   /* a classic key outline: ring and toothed blade */
    CGFloat d = r.size.height * 0.52;
    CGContextAddEllipseInRect(c, CGRectMake(r.origin.x, r.origin.y + (r.size.height - d) / 2, d, d));
}

void TBDrawIcon(CGContextRef c, int kind, CGRect r, UIColor *color) {
    CGContextSaveGState(c);
    [color setStroke]; [color setFill];
    CGFloat s = MIN(r.size.width, r.size.height);
    CGFloat x = CGRectGetMidX(r) - s / 2, y = CGRectGetMidY(r) - s / 2;
    CGContextSetLineWidth(c, s * 0.09);
    CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
#define P(px, py) CGPointMake(x + (px) * s, y + (py) * s)
    if (kind == 0) {            /* scan: viewfinder corners around a small code */
        CGFloat a = 0.08, b = 0.92, l = 0.30;
        CGPoint cs[4][3] = {{P(a, a + l), P(a, a), P(a + l, a)}, {P(b - l, a), P(b, a), P(b, a + l)}, {P(b, b - l), P(b, b), P(b - l, b)}, {P(a + l, b), P(a, b), P(a, b - l)}};
        for (int i = 0; i < 4; i++) { CGContextMoveToPoint(c, cs[i][0].x, cs[i][0].y); CGContextAddLineToPoint(c, cs[i][1].x, cs[i][1].y); CGContextAddLineToPoint(c, cs[i][2].x, cs[i][2].y); }
        CGContextStrokePath(c);
        CGContextFillRect(c, CGRectMake(x + 0.30 * s, y + 0.30 * s, 0.16 * s, 0.16 * s));
        CGContextFillRect(c, CGRectMake(x + 0.54 * s, y + 0.30 * s, 0.16 * s, 0.16 * s));
        CGContextFillRect(c, CGRectMake(x + 0.30 * s, y + 0.54 * s, 0.16 * s, 0.16 * s));
        CGContextFillRect(c, CGRectMake(x + 0.58 * s, y + 0.58 * s, 0.12 * s, 0.12 * s));
    } else if (kind == 1) {     /* add: key with a plus on its ring */
        CGContextSetLineWidth(c, s * 0.11);
        CGContextMoveToPoint(c, x + 0.5 * s, y + 0.14 * s); CGContextAddLineToPoint(c, x + 0.5 * s, y + 0.86 * s);
        CGContextMoveToPoint(c, x + 0.14 * s, y + 0.5 * s); CGContextAddLineToPoint(c, x + 0.86 * s, y + 0.5 * s);
        CGContextStrokePath(c);
    } else if (kind == 2) {     /* settings: gear */
        CGPoint m = P(0.5, 0.5);
        for (int i = 0; i < 8; i++) {
            CGFloat a = i * M_PI / 4;
            CGContextMoveToPoint(c, m.x + cos(a) * s * 0.30, m.y + sin(a) * s * 0.30);
            CGContextAddLineToPoint(c, m.x + cos(a) * s * 0.46, m.y + sin(a) * s * 0.46);
        }
        CGContextSetLineWidth(c, s * 0.15); CGContextStrokePath(c);
        CGContextSetLineWidth(c, s * 0.10);
        CGContextStrokeEllipseInRect(c, CGRectMake(x + 0.24 * s, y + 0.24 * s, 0.52 * s, 0.52 * s));
        CGContextFillEllipseInRect(c, CGRectMake(x + 0.43 * s, y + 0.43 * s, 0.14 * s, 0.14 * s));
    } else if (kind == 3) {     /* lock */
        CGContextSetLineWidth(c, s * 0.11);
        CGContextAddArc(c, x + 0.5 * s, y + 0.38 * s, 0.22 * s, M_PI, 0, 0);
        CGContextAddLineToPoint(c, x + 0.72 * s, y + 0.48 * s);
        CGContextMoveToPoint(c, x + 0.28 * s, y + 0.38 * s); CGContextAddLineToPoint(c, x + 0.28 * s, y + 0.48 * s);
        CGContextStrokePath(c);
        TBRoundRectPath(c, CGRectMake(x + 0.16 * s, y + 0.46 * s, 0.68 * s, 0.46 * s), s * 0.07); CGContextFillPath(c);
    } else if (kind == 4) {     /* photo */
        TBRoundRectPath(c, CGRectMake(x + 0.08 * s, y + 0.18 * s, 0.84 * s, 0.64 * s), s * 0.08); CGContextStrokePath(c);
        CGContextMoveToPoint(c, x + 0.16 * s, y + 0.72 * s); CGContextAddLineToPoint(c, x + 0.38 * s, y + 0.46 * s);
        CGContextAddLineToPoint(c, x + 0.54 * s, y + 0.62 * s); CGContextAddLineToPoint(c, x + 0.66 * s, y + 0.50 * s);
        CGContextAddLineToPoint(c, x + 0.84 * s, y + 0.72 * s); CGContextStrokePath(c);
        CGContextFillEllipseInRect(c, CGRectMake(x + 0.62 * s, y + 0.28 * s, 0.12 * s, 0.12 * s));
    } else if (kind == 5) {     /* clipboard */
        TBRoundRectPath(c, CGRectMake(x + 0.2 * s, y + 0.16 * s, 0.6 * s, 0.76 * s), s * 0.07); CGContextStrokePath(c);
        TBRoundRectPath(c, CGRectMake(x + 0.35 * s, y + 0.06 * s, 0.3 * s, 0.18 * s), s * 0.05); CGContextFillPath(c);
        CGContextMoveToPoint(c, x + 0.32 * s, y + 0.46 * s); CGContextAddLineToPoint(c, x + 0.68 * s, y + 0.46 * s);
        CGContextMoveToPoint(c, x + 0.32 * s, y + 0.64 * s); CGContextAddLineToPoint(c, x + 0.68 * s, y + 0.64 * s);
        CGContextStrokePath(c);
    } else {                    /* key */
        keyShape(c, CGRectMake(x, y, s, s));
        CGContextStrokePath(c);
        CGContextMoveToPoint(c, x + 0.5 * s, y + 0.5 * s); CGContextAddLineToPoint(c, x + 0.94 * s, y + 0.5 * s);
        CGContextMoveToPoint(c, x + 0.78 * s, y + 0.5 * s); CGContextAddLineToPoint(c, x + 0.78 * s, y + 0.68 * s);
        CGContextMoveToPoint(c, x + 0.90 * s, y + 0.5 * s); CGContextAddLineToPoint(c, x + 0.90 * s, y + 0.64 * s);
        CGContextStrokePath(c);
    }
#undef P
    CGContextRestoreGState(c);
}

/* The padlock: steel shackle through a brass body with a keyhole. Same drawing as the app icon (make_assets.py is its twin). */
UIImage *TBPadlockImage(CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat s = size / 100.0;
    CGContextScaleCTM(c, s, s);
    /* shackle: thick steel U drawn as stacked strokes, dark to light, for a tubular look */
    CGFloat cw[5] = {11, 9, 6.5, 3.5, 1.4};
    UIColor *cc[5] = {TBRGB(30, 32, 38), TBRGB(96, 102, 114), TBRGB(168, 174, 186), TBRGB(226, 230, 238), TBRGB(255, 255, 255)};
    for (int i = 0; i < 5; i++) {
        CGContextSetLineWidth(c, cw[i]); [cc[i] setStroke]; CGContextSetLineCap(c, kCGLineCapButt);
        CGContextMoveToPoint(c, 33 - (i > 2 ? 1.2 : 0), 52); CGContextAddLineToPoint(c, 33 - (i > 2 ? 1.2 : 0), 36);
        CGContextAddArc(c, 50, 36, 17 - (i > 2 ? 1.2 : 0), M_PI, 0, 0);
        CGContextAddLineToPoint(c, 67 - (i > 2 ? 1.2 : 0), 52);
        CGContextStrokePath(c);
    }
    CGRect body = CGRectMake(22, 47, 56, 42);
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 4, [UIColor colorWithWhite:0 alpha:0.6].CGColor);
    TBRoundRectPath(c, body, 8); [TB_BRASS_DK setFill]; CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    TBRoundRectPath(c, body, 8); CGContextClip(c);
    TBFillGradient(c, body, TBRGB(250, 222, 140), TBRGB(168, 118, 34));
    TBFillGradient(c, CGRectMake(body.origin.x, body.origin.y, body.size.width, 16), [UIColor colorWithWhite:1 alpha:0.5], [UIColor colorWithWhite:1 alpha:0.05]);
    CGContextRestoreGState(c);
    TBRoundRectPath(c, CGRectInset(body, 0.4, 0.4), 8); [TBRGB(92, 58, 12) setStroke]; CGContextSetLineWidth(c, 0.9); CGContextStrokePath(c);
    /* keyhole */
    [TBRGB(36, 22, 6) setFill];
    CGContextFillEllipseInRect(c, CGRectMake(44, 58, 12, 12));
    CGContextMoveToPoint(c, 47, 66); CGContextAddLineToPoint(c, 53, 66); CGContextAddLineToPoint(c, 55, 79); CGContextAddLineToPoint(c, 45, 79); CGContextClosePath(c); CGContextFillPath(c);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}
