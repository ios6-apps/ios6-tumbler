#import "TBChrome.h"

/* Camera QR scanner (frames go through the bundled quirc decoder) with a photo-library fallback. */
@interface TBScanController : TBScreen
@property (nonatomic) BOOL startWithPhoto;
@end
