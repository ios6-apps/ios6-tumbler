#import <UIKit/UIKit.h>

/* Four-digit passcode keypad that covers the whole window. */
@interface TBLockView : UIView
/* onEntry gets the four digits and returns YES to accept them (the keypad then leaves); NO shakes and clears.
   cancel, when set, adds a Cancel key. */
+ (TBLockView *)presentIn:(UIWindow *)window prompt:(NSString *)prompt onEntry:(BOOL (^)(NSString *pin))onEntry cancel:(void (^)(void))cancel;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, copy) NSString *promptText;
- (void)clearEntry;
- (void)dismissAnimated;
@end

/* the three PIN flows built on it */
void TBLockSetNewPIN(UIWindow *w, void (^done)(NSString *pin));     /* asks twice; pin is nil when cancelled */
void TBLockVerifyPIN(UIWindow *w, NSString *prompt, void (^done)(BOOL ok));
