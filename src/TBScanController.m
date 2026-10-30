#import "TBScanController.h"
#import "TBStore.h"
#import "TBQR.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface TBFinder : UIView
@property (nonatomic) BOOL found;
@end

@implementation TBFinder {
    CALayer *_line;
}
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor]; self.opaque = NO;
        self.userInteractionEnabled = NO;
        _line = [CALayer layer];
        _line.backgroundColor = TBRGB(255, 190, 60).CGColor;
        _line.shadowColor = TBRGB(255, 170, 30).CGColor; _line.shadowOpacity = 1; _line.shadowRadius = 5; _line.shadowOffset = CGSizeZero;
        [self.layer addSublayer:_line];
    }
    return self;
}
- (CGRect)finderRect {
    CGFloat s = MIN(self.bounds.size.width - 64, 250);
    return CGRectMake((self.bounds.size.width - s) / 2, (self.bounds.size.height - s) / 2 - 24, s, s);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect w = [self finderRect];
    _line.frame = CGRectMake(w.origin.x + 8, w.origin.y + 6, w.size.width - 16, 2);
    [_line removeAllAnimations];
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"position.y"];
    a.fromValue = [NSNumber numberWithFloat:w.origin.y + 8]; a.toValue = [NSNumber numberWithFloat:CGRectGetMaxY(w) - 8];
    a.duration = 1.8; a.autoreverses = YES; a.repeatCount = HUGE_VALF;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_line addAnimation:a forKey:@"sweep"];
}
- (void)setFound:(BOOL)f { _found = f; _line.hidden = f; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect w = [self finderRect];
    /* dim everything but the window */
    [[UIColor colorWithWhite:0 alpha:0.62] setFill];
    CGContextAddRect(c, self.bounds);
    TBRoundRectPath(c, w, 6);
    CGContextEOFillPath(c);
    /* brass corner brackets */
    UIColor *col = _found ? TBRGB(110, 220, 120) : TBRGB(232, 190, 96);
    CGFloat L = 34, in = -3;
    CGRect r = CGRectInset(w, in, in);
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5), 2, [UIColor colorWithWhite:0 alpha:0.9].CGColor);
    [col setStroke];
    CGContextSetLineWidth(c, 5); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
    CGFloat x0 = r.origin.x, y0 = r.origin.y, x1 = CGRectGetMaxX(r), y1 = CGRectGetMaxY(r);
    CGContextMoveToPoint(c, x0, y0 + L); CGContextAddArcToPoint(c, x0, y0, x0 + L, y0, 8); CGContextAddLineToPoint(c, x0 + L, y0);
    CGContextMoveToPoint(c, x1 - L, y0); CGContextAddArcToPoint(c, x1, y0, x1, y0 + L, 8); CGContextAddLineToPoint(c, x1, y0 + L);
    CGContextMoveToPoint(c, x1, y1 - L); CGContextAddArcToPoint(c, x1, y1, x1 - L, y1, 8); CGContextAddLineToPoint(c, x1 - L, y1);
    CGContextMoveToPoint(c, x0 + L, y1); CGContextAddArcToPoint(c, x0, y1, x0, y1 - L, 8); CGContextAddLineToPoint(c, x0, y1 - L);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);
    if (_found) {   /* tick mark in the middle */
        CGPoint m = CGPointMake(CGRectGetMidX(w), CGRectGetMidY(w));
        CGContextSetLineWidth(c, 12); [col setStroke]; CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextMoveToPoint(c, m.x - 28, m.y + 2); CGContextAddLineToPoint(c, m.x - 8, m.y + 22); CGContextAddLineToPoint(c, m.x + 30, m.y - 22);
        CGContextStrokePath(c);
    }
}
@end

@interface TBScanController () <AVCaptureVideoDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation TBScanController {
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureVideoPreviewLayer *_preview;
    dispatch_queue_t _queue;
    TBQRDecoder *_decoder;
    TBFinder *_finder;
    UILabel *_hint;
    TBButton *_torch;
    BOOL _done;
    int _frame;
    NSString *_lastBad;
    NSTimeInterval _lastBadAt;
    BOOL _pickerShown;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setScreenTitle:@"Scan QR Code"];
    self.view.backgroundColor = [UIColor blackColor];
    self.leftButton = [[TBButton alloc] initWithTitle:@"Cancel" tone:0];
    [self.leftButton addTarget:self action:@selector(dismissScreen) forControlEvents:UIControlEventTouchUpInside];
    TBButton *photo = [[TBButton alloc] initWithIcon:4 title:@"Photo" flat:NO];
    photo.bounds = CGRectMake(0, 0, 70, 30);
    self.rightButton = photo;
    [self.rightButton addTarget:self action:@selector(pickPhoto) forControlEvents:UIControlEventTouchUpInside];
    self.content.backgroundColor = [UIColor blackColor];
    CGRect cb = self.content.bounds;
    _decoder = [[TBQRDecoder alloc] init];
    _queue = dispatch_queue_create("tumbler.scan", DISPATCH_QUEUE_SERIAL);

    _finder = [[TBFinder alloc] initWithFrame:cb];
    _finder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.content addSubview:_finder];

    _hint = [[UILabel alloc] initWithFrame:CGRectMake(20, cb.size.height - 92, cb.size.width - 40, 44)];
    _hint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _hint.backgroundColor = [UIColor clearColor]; _hint.textColor = TB_CREAM; _hint.numberOfLines = 2;
    _hint.textAlignment = NSTextAlignmentCenter; _hint.font = TBFont(@"HelveticaNeue", 14);
    _hint.shadowColor = [UIColor blackColor]; _hint.shadowOffset = CGSizeMake(0, -1);
    _hint.text = @"Hold the code inside the frame.\nNo button to press, it reads on its own.";
    [self.content addSubview:_hint];

    _torch = [[TBButton alloc] initWithTitle:@"Light" tone:0];
    _torch.center = CGPointMake(cb.size.width / 2, cb.size.height - 28);
    _torch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [_torch addTarget:self action:@selector(toggleTorch) forControlEvents:UIControlEventTouchUpInside];
    _torch.hidden = YES;
    [self.content addSubview:_torch];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.startWithPhoto && !_pickerShown) { _pickerShown = YES; [self pickPhoto]; return; }
    [self startCamera];
}

- (void)startCamera {
    if (_session) { dispatch_async(_queue, ^{ [_session startRunning]; }); return; }
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *err = nil;
    AVCaptureDeviceInput *in = _device ? [AVCaptureDeviceInput deviceInputWithDevice:_device error:&err] : nil;
    if (!in) {
        _hint.text = err ? @"The camera is blocked. Allow it for Tumbler in Settings > Privacy > Camera, or use a photo of the code." : @"No camera here. Use a photo of the code instead.";
        [_finder removeFromSuperview];
        return;
    }
    _session = [[AVCaptureSession alloc] init];
    if ([_session canSetSessionPreset:AVCaptureSessionPreset640x480]) _session.sessionPreset = AVCaptureSessionPreset640x480;
    [_session addInput:in];
    AVCaptureVideoDataOutput *out = [[AVCaptureVideoDataOutput alloc] init];
    out.alwaysDiscardsLateVideoFrames = YES;
    out.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [out setSampleBufferDelegate:self queue:_queue];
    if ([_session canAddOutput:out]) [_session addOutput:out];
    _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _preview.frame = self.content.bounds;
    [self.content.layer insertSublayer:_preview atIndex:0];
    if ([_device lockForConfiguration:NULL]) {
        if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) _device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [_device respondsToSelector:@selector(isAutoFocusRangeRestrictionSupported)] && _device.autoFocusRangeRestrictionSupported)
            _device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        [_device unlockForConfiguration];
    }
    _torch.hidden = !_device.hasTorch;
    dispatch_async(_queue, ^{ [_session startRunning]; });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!_pickerShown || self.presentedViewController == nil) {
        AVCaptureSession *s = _session;
        dispatch_async(_queue, ^{ [s stopRunning]; });
    }
}

- (void)toggleTorch {
    if (![_device lockForConfiguration:NULL]) return;
    _device.torchMode = _device.torchMode == AVCaptureTorchModeOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
    [_device unlockForConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)o didOutputSampleBuffer:(CMSampleBufferRef)sb fromConnection:(AVCaptureConnection *)conn {
    if (_done || (++_frame % 2)) return;
    CVImageBufferRef pb = CMSampleBufferGetImageBuffer(sb);
    if (!pb) return;
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    const uint8_t *y = CVPixelBufferGetBaseAddressOfPlane(pb, 0);
    int w = (int)CVPixelBufferGetWidthOfPlane(pb, 0), h = (int)CVPixelBufferGetHeightOfPlane(pb, 0), stride = (int)CVPixelBufferGetBytesPerRowOfPlane(pb, 0);
    NSArray *r = y ? [_decoder decodeGray:y width:w height:h stride:stride] : nil;
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    for (NSString *text in r) {
        if ([self handleText:text]) break;
    }
}

/* any thread; YES when the text was a usable key */
- (BOOL)handleText:(NSString *)text {
    NSArray *list = [TBAccount accountsFromText:text];
    if (!list.count) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (!([text isEqualToString:_lastBad] && now - _lastBadAt < 3)) {
            _lastBad = text; _lastBadAt = now;
            dispatch_async(dispatch_get_main_queue(), ^{ if (!_done) TBToast(self.view, @"That is not a 2FA code", NO); });
        }
        return NO;
    }
    _done = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [self finishWith:list]; });
    return YES;
}

- (void)finishWith:(NSArray *)list {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    _finder.found = YES;
    NSUInteger n = [[TBStore shared] addAccounts:list];
    NSString *msg;
    if (!n) msg = @"Already in your list";
    else if (list.count == 1) msg = [NSString stringWithFormat:@"Added %@", [(TBAccount *)list[0] title]];
    else msg = [NSString stringWithFormat:@"Added %lu accounts", (unsigned long)n];
    _hint.text = msg;
    TBToast(self.view, msg, n > 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self dismissScreen]; });
}

#pragma mark photo

- (void)pickPhoto {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) { TBToast(self.view, @"No photo library", NO); return; }
    _pickerShown = YES;
    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate = self;
    [self presentViewController:p animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)p didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    [p dismissViewControllerAnimated:YES completion:^{
        NSArray *r = img ? [_decoder decodeImage:img.CGImage maxSide:1200] : nil;
        if (!r.count && img) r = [_decoder decodeImage:img.CGImage maxSide:2400];
        if (!r.count && img) r = [_decoder decodeImage:img.CGImage maxSide:640];
        BOOL ok = NO;
        for (NSString *t in r) if ([self handleText:t]) { ok = YES; break; }
        if (!ok) {
            if (!r.count) TBToast(self.view, @"No QR code found in that photo", NO);
            if (!_session) [self dismissScreen];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)p {
    [p dismissViewControllerAnimated:YES completion:^{ if (!_session) [self dismissScreen]; }];
}

- (void)dealloc { [_session stopRunning]; }

@end
