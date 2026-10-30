#import "TBCards.h"
#import "TBStyle.h"
#import "TBStore.h"

@interface TBDial : UIControl
@property (nonatomic) double fraction;      /* elapsed share of the period, 0..1 */
@property (nonatomic) double secondsLeft;
@property (nonatomic) BOOL counter;
@property (nonatomic) long long count;
@end

@implementation TBDial
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; } return self; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 1, 1);
    CGPoint m = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    CGFloat R = b.size.width / 2;
    /* drop shadow + chrome bezel */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 2), 3, [UIColor colorWithWhite:0 alpha:0.8].CGColor);
    [TBRGB(10, 10, 12) setFill]; CGContextFillEllipseInRect(c, b);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, b); CGContextClip(c);
    TBFillGradient(c, b, TBRGB(250, 252, 255), TBRGB(70, 74, 84));
    CGContextRestoreGState(c);
    CGRect ring = CGRectInset(b, 3.5, 3.5);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, ring); CGContextClip(c);
    TBFillGradient(c, ring, TBRGB(60, 64, 72), TBRGB(224, 228, 236));
    CGContextRestoreGState(c);
    CGRect face = CGRectInset(b, 5, 5);
    CGFloat fr = face.size.width / 2;

    if (_counter) {   /* HOTP: a brass push knob that advances the counter */
        CGContextSaveGState(c);
        CGContextAddEllipseInRect(c, face); CGContextClip(c);
        if (self.highlighted) TBFillGradient(c, face, TBRGB(170, 122, 40), TBRGB(236, 200, 112));
        else TBFillGradient(c, face, TBRGB(246, 218, 134), TBRGB(166, 116, 34));
        TBFillGradient(c, CGRectMake(face.origin.x, face.origin.y, face.size.width, fr), [UIColor colorWithWhite:1 alpha:0.45], [UIColor colorWithWhite:1 alpha:0.04]);
        CGContextRestoreGState(c);
        UIFont *f = TBFont(@"HelveticaNeue-Bold", 15);
        NSString *n = [NSString stringWithFormat:@"%lld", _count];
        TBDrawText(n, CGRectMake(face.origin.x, m.y - 12, face.size.width, 18), f, TBRGB(70, 42, 6), [UIColor colorWithWhite:1 alpha:0.5], 1, NSTextAlignmentCenter);
        TBDrawText(@"NEXT", CGRectMake(face.origin.x, m.y + 3, face.size.width, 10), TBFont(@"HelveticaNeue-Bold", 8), TBRGB(90, 56, 10), [UIColor colorWithWhite:1 alpha:0.4], 1, NSTextAlignmentCenter);
        return;
    }

    /* cream face */
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, face); CGContextClip(c);
    TBFillGradient(c, face, TBRGB(252, 248, 234), TBRGB(214, 204, 176));
    /* remaining time as a coloured wedge that shrinks as the hand sweeps */
    UIColor *wedge = _secondsLeft > 10 ? TBRGB(72, 170, 84) : _secondsLeft > 5 ? TBRGB(236, 164, 36) : TBRGB(214, 56, 44);
    CGFloat a0 = -M_PI_2 + 2 * M_PI * _fraction, a1 = 1.5 * M_PI;
    CGContextMoveToPoint(c, m.x, m.y);
    CGContextAddArc(c, m.x, m.y, fr, a0, a1, 0);
    CGContextClosePath(c);
    CGContextSetFillColorWithColor(c, [wedge colorWithAlphaComponent:0.55].CGColor);
    CGContextFillPath(c);
    CGContextRestoreGState(c);
    /* ticks */
    for (int i = 0; i < 60; i++) {
        CGFloat a = i * M_PI / 30 - M_PI_2, major = (i % 5 == 0);
        CGFloat r0 = fr - (major ? 7 : 4.5), r1 = fr - 1.5;
        [TBRGB(40, 36, 28) setStroke];
        CGContextSetLineWidth(c, major ? 1.4 : 0.6);
        CGContextMoveToPoint(c, m.x + cos(a) * r0, m.y + sin(a) * r0);
        CGContextAddLineToPoint(c, m.x + cos(a) * r1, m.y + sin(a) * r1);
        CGContextStrokePath(c);
    }
    /* hand */
    CGFloat ha = -M_PI_2 + 2 * M_PI * _fraction;
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(1, 1.5), 1.5, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
    [TBRGB(150, 24, 18) setStroke];
    CGContextSetLineWidth(c, 1.6); CGContextSetLineCap(c, kCGLineCapRound);
    CGContextMoveToPoint(c, m.x - cos(ha) * 7, m.y - sin(ha) * 7);
    CGContextAddLineToPoint(c, m.x + cos(ha) * (fr - 5), m.y + sin(ha) * (fr - 5));
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGRect cap = CGRectMake(m.x - 3.5, m.y - 3.5, 7, 7);
    CGContextAddEllipseInRect(c, cap); CGContextClip(c);
    TBFillGradient(c, cap, TBRGB(250, 222, 140), TBRGB(140, 96, 24));
    CGContextRestoreGState(c);
    /* glass */
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, face); CGContextClip(c);
    CGRect gl = CGRectMake(face.origin.x + 3, face.origin.y + 1.5, face.size.width - 6, face.size.height * 0.46);
    CGContextAddEllipseInRect(c, gl); CGContextClip(c);
    TBFillGradient(c, gl, [UIColor colorWithWhite:1 alpha:0.62], [UIColor colorWithWhite:1 alpha:0.06]);
    CGContextRestoreGState(c);
    CGContextAddEllipseInRect(c, face); [TBRGB(60, 54, 40) setStroke]; CGContextSetLineWidth(c, 0.8); CGContextStrokePath(c);
}
@end

@interface TBLCD : UIView
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL warn;
@property (nonatomic) BOOL covered;
@property (nonatomic) long long stepDrawn;
@end

@implementation TBLCD
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 0, 1);
    b.size.height -= 1;
    TBLCDPanel(c, b);
    CGRect in = CGRectInset(b, 10, 6);
    NSString *shape = _text.length ? _text : @"888 888";
    if (_covered) {   /* unlit segments only (non-digits have no lit segments), plus a hint */
        NSMutableString *ghost = [NSMutableString string];
        for (NSUInteger i = 0; i < shape.length; i++) [ghost appendString:[shape characterAtIndex:i] == ' ' ? @" " : @"x"];
        TBDrawSegments(c, in, ghost, TB_AMBER, YES);
        TBDrawText(@"TAP TO REVEAL", CGRectMake(b.origin.x, b.origin.y + (b.size.height - 14) / 2, b.size.width, 14), TBFont(@"HelveticaNeue-Bold", 12), [TB_AMBER colorWithAlphaComponent:0.75], nil, 0, NSTextAlignmentCenter);
    } else {
        UIColor *lit = _warn ? TBRGB(255, 96, 52) : TB_AMBER;
        TBDrawSegments(c, in, shape, lit, YES);
    }
    /* glass reflection across the top of the panel */
    CGContextSaveGState(c);
    TBRoundRectPath(c, b, 5); CGContextClip(c);
    TBFillGradient(c, CGRectMake(b.origin.x, b.origin.y, b.size.width, b.size.height * 0.45), [UIColor colorWithWhite:1 alpha:0.16], [UIColor colorWithWhite:1 alpha:0.02]);
    CGContextRestoreGState(c);
}
@end

@implementation TBCardView {
    TBDial *_dial;
    TBLCD *_lcd;
    NSString *_shownCode;
    long long _shownStep;
}

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _dial = [[TBDial alloc] initWithFrame:CGRectMake(14, 18, 62, 62)];
        [_dial addTarget:self action:@selector(advance) forControlEvents:UIControlEventTouchUpInside];
        _lcd = [[TBLCD alloc] initWithFrame:CGRectZero];
        _lcd.userInteractionEnabled = NO;
        [self addSubview:_dial]; [self addSubview:_lcd];
        _shownStep = -1;
    }
    return self;
}

- (void)advance { if (_onAdvance) _onAdvance(); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _lcd.frame = CGRectMake(88, 56, w - 88 - 12, 36);
    _dial.frame = CGRectMake(14, 17, 62, 62);
}

- (void)setAccount:(TBAccount *)a {
    _account = a;
    _shownStep = -1;
    _dial.counter = a.counterBased;
    [self setNeedsDisplay];
    [self tick:[NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970];
}

- (void)setCovered:(BOOL)c { _covered = c; _lcd.covered = c; [_lcd setNeedsDisplay]; }

static NSString *group(NSString *code) {
    NSUInteger n = code.length, k = n <= 6 ? n / 2 : (n + 1) / 2;
    return [NSString stringWithFormat:@"%@ %@", [code substringToIndex:k], [code substringFromIndex:k]];
}

- (void)tick:(NSTimeInterval)now {
    if (!_account) return;
    now = [TBStore now];
    if (_account.counterBased) {
        long long step = _account.counter;
        if (step != _shownStep) {
            _shownStep = step;
            _lcd.text = group([_account codeAtTime:now]);
            _dial.count = step;
            _lcd.warn = NO;
            [_lcd setNeedsDisplay]; [_dial setNeedsDisplay];
        }
        return;
    }
    double left = [_account secondsLeftAtTime:now];
    long long step = (long long)(now / _account.period);
    if (step != _shownStep) {
        _shownStep = step;
        _lcd.text = group([_account codeAtTime:now]);
        _lcd.stepDrawn = -1;
    }
    BOOL warn = left <= 5;
    if (warn != _lcd.warn || step != _lcd.stepDrawn) { _lcd.warn = warn; _lcd.stepDrawn = step; [_lcd setNeedsDisplay]; }
    _dial.secondsLeft = left;
    _dial.fraction = 1 - left / _account.period;
    [_dial setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 0, 0);
    b.size.height -= 6;
    TBPlate(c, b, 10);
    CGFloat w = b.size.width;
    TBScrew(c, CGPointMake(7.5, 8), 3, 0.5); TBScrew(c, CGPointMake(w - 7.5, 8), 3, 1.9);
    TBScrew(c, CGPointMake(7.5, b.size.height - 8), 3, 1.2); TBScrew(c, CGPointMake(w - 7.5, b.size.height - 8), 3, 2.6);
    NSString *issuer = _account.title;
    CGFloat lw = MIN(w - 88 - 14, [[issuer uppercaseString] sizeWithFont:TBFont(@"HelveticaNeue-Bold", 12)].width + 18);
    TBDymo(c, CGRectMake(88, 12, MAX(lw, 54), 22), issuer);
    NSString *sub = _account.issuer.length ? _account.name : (_account.counterBased ? @"counter based" : @"");
    if (_account.issuer.length && _account.counterBased) sub = [sub stringByAppendingString:@" · counter"];
    TBDrawText(sub, CGRectMake(90, 37, w - 90 - 14, 16), TBFont(@"HelveticaNeue", 13), TBRGB(214, 218, 226), [UIColor colorWithWhite:0 alpha:0.85], -1, NSTextAlignmentLeft);
}

@end

@implementation TBAccountCell {
    TBCardView *_card;
}

- (id)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:s reuseIdentifier:rid])) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundView = nil;
        _card = [[TBCardView alloc] initWithFrame:CGRectMake(8, 4, 304, 106)];
        [self.contentView addSubview:_card];
    }
    return self;
}

- (TBCardView *)card { return _card; }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    _card.frame = CGRectMake(8, 0, b.size.width - 16, b.size.height);
}

@end
