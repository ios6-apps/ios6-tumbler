#import <Foundation/Foundation.h>
#import "TBOTP.h"

extern NSString *const TBStoreChanged;

@interface TBStore : NSObject
+ (TBStore *)shared;
@property (nonatomic, readonly) NSArray *accounts;
- (BOOL)addAccount:(TBAccount *)a;                  /* NO when the same key is already there */
- (NSUInteger)addAccounts:(NSArray *)list;          /* returns how many were new */
- (void)removeAccountAtIndex:(NSUInteger)i;
- (void)moveAccountFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (void)replaceAccountAtIndex:(NSUInteger)i with:(TBAccount *)a;
- (void)save;                                       /* after mutating an account in place (HOTP counter) */
- (NSString *)exportText;                           /* one otpauth:// URI per line */

/* clock: codes depend on the phone's time, so the store keeps an offset measured against a web server's Date header */
+ (NSTimeInterval)now;
@property (nonatomic) double clockOffset;
+ (NSString *)describeOffset:(double)off;           /* "8 h", "3 min 5 s", "1.2 s" */
- (void)syncClock:(void (^)(BOOL ok, double offset))done;
- (void)syncClockFromHost:(NSUInteger)i done:(void (^)(BOOL ok, double offset))done;

/* settings */
@property (nonatomic) BOOL coverCodes;              /* codes hidden until tapped */
- (BOOL)hasPIN;
- (BOOL)checkPIN:(NSString *)pin;
- (void)setPIN:(NSString *)pin;                     /* nil removes the lock */
@end
