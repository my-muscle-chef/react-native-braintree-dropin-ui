#import <UIKit/UIKit.h>
#import "BraintreeCore.h"
#import "BTCardNonce.h"

typedef void (^BTCardFormCompletion)(BTCardNonce * _Nullable nonce, NSError * _Nullable error);
typedef void (^BTCardFormCancel)(void);

@interface BTCardFormViewController : UIViewController

- (instancetype)initWithAPIClient:(BTAPIClient *)apiClient
                       completion:(BTCardFormCompletion)completion
                         onCancel:(BTCardFormCancel)onCancel;

@end
