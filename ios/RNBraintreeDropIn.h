@import UIKit;
@import PassKit;

#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

@class BTDataCollector;

@interface RNBraintreeDropIn : NSObject <RCTBridgeModule, PKPaymentAuthorizationViewControllerDelegate>

@property (nonatomic, strong) UIViewController *_Nonnull reactRoot;
@property (nonatomic, copy)   NSString *_Nullable clientToken;
@property (nonatomic, strong) BTDataCollector *_Nullable dataCollector;
@property (nonatomic, strong) PKPaymentRequest *_Nonnull paymentRequest;
@property (nonatomic, strong) PKPaymentAuthorizationViewController *_Nonnull viewController;
@property (nonatomic, copy)   NSString *_Nonnull deviceDataCollector;
@property (nonatomic)         RCTPromiseResolveBlock _Nonnull resolve;
@property (nonatomic)         RCTPromiseRejectBlock  _Nonnull reject;
@property (nonatomic, assign) BOOL applePayAuthorized;

@end
