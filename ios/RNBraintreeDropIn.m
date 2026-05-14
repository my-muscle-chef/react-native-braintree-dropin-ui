#import "RNBraintreeDropIn.h"
#import "RNBTCardFormViewController.h"
#import <React/RCTUtils.h>

@import BraintreeCore;
@import BraintreePayPal;
@import BraintreeCard;
@import BraintreeApplePay;
@import BraintreeDataCollector;

@implementation RNBraintreeDropIn

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE(RNBraintreeDropIn)

RCT_EXPORT_METHOD(showApplePay:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }

    NSString* merchantIdentifier = options[@"merchantIdentifier"];
    NSString* countryCode = options[@"countryCode"];
    NSString* currencyCode = options[@"currencyCode"];
    NSString* merchantName = options[@"merchantName"];
    NSString* orderTotalStr = options[@"orderTotal"];

    if (!merchantIdentifier || !countryCode || !currencyCode || !merchantName || !orderTotalStr) {
        reject(@"MISSING_OPTIONS", @"Not all required Apple Pay options were provided", nil);
        return;
    }

    self.resolve = resolve;
    self.reject = reject;
    self.applePayAuthorized = NO;
    self.deviceDataCollector = @"";
    self.clientToken = clientToken;

    self.dataCollector = [[BTDataCollector alloc] initWithAuthorization:clientToken];
    [self.dataCollector collectDeviceData:^(NSString *deviceData, NSError *error) {
        self.deviceDataCollector = deviceData ?: @"";
    }];

    self.paymentRequest = [[PKPaymentRequest alloc] init];
    self.paymentRequest.merchantIdentifier = merchantIdentifier;
    self.paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
    self.paymentRequest.countryCode = countryCode;
    self.paymentRequest.currencyCode = currencyCode;
    self.paymentRequest.supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkDiscover, PKPaymentNetworkChinaUnionPay];
    self.paymentRequest.paymentSummaryItems = @[
        [PKPaymentSummaryItem summaryItemWithLabel:merchantName amount:[NSDecimalNumber decimalNumberWithString:orderTotalStr]]
    ];

    self.viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:self.paymentRequest];
    self.viewController.delegate = self;

    UIViewController *rootViewController = RCTPresentedViewController();
    [rootViewController presentViewController:self.viewController animated:YES completion:nil];
}

RCT_EXPORT_METHOD(showPayPal:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }

    self.resolve = resolve;
    self.reject = reject;
    self.deviceDataCollector = @"";

    self.dataCollector = [[BTDataCollector alloc] initWithAuthorization:clientToken];
    [self.dataCollector collectDeviceData:^(NSString *deviceData, NSError *error) {
        self.deviceDataCollector = deviceData ?: @"";
    }];

    __block BTPayPalClient *payPalClient = [[BTPayPalClient alloc] initWithAuthorization:clientToken];

    void (^completionBlock)(BTPayPalAccountNonce*, NSError*) = ^(BTPayPalAccountNonce *nonce, NSError *error) {
        payPalClient = nil;
        if (error) {
            self.reject(error.localizedDescription, error.localizedDescription, error);
        } else if (!nonce) {
            self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
        } else {
            NSMutableDictionary* result = [NSMutableDictionary new];
            [result setObject:nonce.nonce forKey:@"nonce"];
            [result setObject:@"PayPal" forKey:@"type"];
            [result setObject:nonce.email ?: @"PayPal" forKey:@"description"];
            [result setObject:@(nonce.isDefault) forKey:@"isDefault"];
            [result setObject:self.deviceDataCollector ?: @"" forKey:@"deviceData"];
            self.resolve(result);
        }
    };

    NSString *amount = options[@"amount"];
    if (amount) {
        BTPayPalCheckoutRequest *checkoutRequest = [[BTPayPalCheckoutRequest alloc] initWithAmount:amount];
        if (options[@"currencyCode"]) {
            checkoutRequest.currencyCode = options[@"currencyCode"];
        }
        [payPalClient tokenizeWithCheckoutRequest:checkoutRequest completion:completionBlock];
    } else {
        [payPalClient tokenizeWithVaultRequest:[[BTPayPalVaultRequest alloc] init] completion:completionBlock];
    }
}

RCT_EXPORT_METHOD(showCardForm:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }

    self.resolve = resolve;
    self.reject = reject;
    self.deviceDataCollector = @"";

    self.dataCollector = [[BTDataCollector alloc] initWithAuthorization:clientToken];
    [self.dataCollector collectDeviceData:^(NSString *deviceData, NSError *error) {
        self.deviceDataCollector = deviceData ?: @"";
    }];

    RNBTCardFormViewController *cardFormVC = [[RNBTCardFormViewController alloc]
        initWithAuthorization:clientToken
        fontFamily:options[@"fontFamily"]
        boldFontFamily:options[@"boldFontFamily"]
        completion:^(BTCardNonce * _Nullable nonce, NSError * _Nullable error) {
            if (error) {
                self.reject(error.localizedDescription, error.localizedDescription, error);
            } else if (!nonce) {
                self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
            } else {
                NSMutableDictionary* result = [NSMutableDictionary new];
                [result setObject:nonce.nonce forKey:@"nonce"];
                [result setObject:nonce.type forKey:@"type"];
                [result setObject:nonce.lastFour ?: @"" forKey:@"description"];
                [result setObject:@(nonce.isDefault) forKey:@"isDefault"];
                [result setObject:self.deviceDataCollector ?: @"" forKey:@"deviceData"];
                self.resolve(result);
            }
        }
        onCancel:^{
            self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
        }];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:cardFormVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    navController.overrideUserInterfaceStyle = [options[@"darkTheme"] boolValue]
        ? UIUserInterfaceStyleDark
        : UIUserInterfaceStyleLight;
    UIViewController *rootViewController = RCTPresentedViewController();
    [rootViewController presentViewController:navController animated:YES completion:nil];
}

RCT_EXPORT_METHOD(getDeviceData:(NSString*)clientToken resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    BTDataCollector *dataCollector = [[BTDataCollector alloc] initWithAuthorization:clientToken];
    [dataCollector collectDeviceData:^(NSString *deviceData, NSError *error) {
        if (error) {
            reject(@"ERROR", @"Error collecting device data", error);
        } else {
            resolve(deviceData);
        }
    }];
}

RCT_EXPORT_METHOD(tokenizeCard:(NSString*)clientToken
                          info:(NSDictionary*)cardInfo
                      resolver:(RCTPromiseResolveBlock)resolve
                      rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *number = cardInfo[@"number"];
    NSString *expirationMonth = cardInfo[@"expirationMonth"];
    NSString *expirationYear = cardInfo[@"expirationYear"];
    NSString *cvv = cardInfo[@"cvv"];
    NSString *postalCode = cardInfo[@"postalCode"];

    if (!number || !expirationMonth || !expirationYear || !cvv || !postalCode) {
        reject(@"INVALID_CARD_INFO", @"Invalid card info", nil);
        return;
    }

    BTCardClient *cardClient = [[BTCardClient alloc] initWithAuthorization:clientToken];
    BTCard *card = [[BTCard alloc] init];
    card.number = number;
    card.expirationMonth = expirationMonth;
    card.expirationYear = expirationYear;
    card.cvv = cvv;
    card.postalCode = postalCode;

    [cardClient tokenizeCard:card completion:^(BTCardNonce *tokenizedCard, NSError *error) {
        if (error == nil) {
            resolve(tokenizedCard.nonce);
        } else {
            reject(@"TOKENIZE_ERROR", @"Error tokenizing card.", error);
        }
    }];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                   handler:(nonnull void (^)(PKPaymentAuthorizationResult * _Nonnull))completion
{
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAuthorization:self.clientToken];
    [applePayClient tokenizeApplePayPayment:payment
                                 completion:^(BTApplePayCardNonce *tokenizedApplePayPayment, NSError *error) {
        if (tokenizedApplePayPayment) {
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
            self.applePayAuthorized = YES;

            NSMutableDictionary* result = [NSMutableDictionary new];
            [result setObject:tokenizedApplePayPayment.nonce forKey:@"nonce"];
            [result setObject:@"Apple Pay" forKey:@"type"];
            [result setObject:[NSString stringWithFormat:@"%@", tokenizedApplePayPayment.type] forKey:@"description"];
            [result setObject:@NO forKey:@"isDefault"];
            [result setObject:self.deviceDataCollector forKey:@"deviceData"];
            self.resolve(result);
        } else {
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
        }
    }];
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
    [self.reactRoot dismissViewControllerAnimated:YES completion:nil];
    if (self.applePayAuthorized == NO) {
        self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
    }
}

- (UIViewController*)reactRoot {
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *maybeModal = root.presentedViewController;
    return maybeModal ?: root;
}

@end
