#import "TBChrome.h"
#import "TBOTP.h"

/* Add an account by hand, or edit an existing one. */
@interface TBFormController : TBScreen <UITextFieldDelegate, UIAlertViewDelegate>
- (id)initWithAccount:(TBAccount *)a index:(NSInteger)i;   /* nil account = new */
@end
