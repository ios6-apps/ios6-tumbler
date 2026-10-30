#import <UIKit/UIKit.h>

@interface TBAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
- (void)lock;                           /* covers the app with the keypad when a PIN is set */
- (void)handleText:(NSString *)text;    /* adds accounts from a URI; shows the result */
@end
