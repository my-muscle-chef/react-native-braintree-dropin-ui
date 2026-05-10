#import <UIKit/UIKit.h>
#import "BraintreeCore.h"
#import "BTCardNonce.h"

typedef void (^BTCardFormCompletion)(BTCardNonce * _Nullable nonce, NSError * _Nullable error);
typedef void (^BTCardFormCancel)(void);

@interface RNBTCardFormViewController : UIViewController

- (instancetype)initWithAPIClient:(BTAPIClient *)apiClient
                       fontFamily:(NSString * _Nullable)fontFamily
                   boldFontFamily:(NSString * _Nullable)boldFontFamily
                       completion:(BTCardFormCompletion)completion
                         onCancel:(BTCardFormCancel)onCancel;

@end
