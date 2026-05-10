#import "RNBTCardFormViewController.h"
#import "BraintreeDropIn.h"

typedef NS_ENUM(NSInteger, RNBTCardNetwork) {
    RNBTCardNetworkUnknown,
    RNBTCardNetworkVisa,
    RNBTCardNetworkMastercard,
    RNBTCardNetworkAmex,
    RNBTCardNetworkDiscover,
    RNBTCardNetworkJCB,
    RNBTCardNetworkDiners,
};

@interface RNBTCardFormViewController () <UITextFieldDelegate>

@property (nonatomic, strong) BTAPIClient *apiClient;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic, copy) NSString *boldFontFamily;
@property (nonatomic, copy) BTCardFormCompletion completion;
@property (nonatomic, copy) BTCardFormCancel onCancel;

@property (nonatomic, strong) UITextField *cardNumberField;
@property (nonatomic, strong) UILabel *cardTypeBadge;
@property (nonatomic, strong) UITextField *expiryField;
@property (nonatomic, strong) UITextField *cvvField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, assign) RNBTCardNetwork detectedCardNetwork;

@end

@implementation RNBTCardFormViewController

- (instancetype)initWithAPIClient:(BTAPIClient *)apiClient
                       fontFamily:(NSString * _Nullable)fontFamily
                   boldFontFamily:(NSString * _Nullable)boldFontFamily
                       completion:(BTCardFormCompletion)completion
                         onCancel:(BTCardFormCancel)onCancel {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _apiClient = apiClient;
        _fontFamily = [fontFamily copy];
        _boldFontFamily = [boldFontFamily copy];
        _completion = [completion copy];
        _onCancel = [onCancel copy];
        _detectedCardNetwork = RNBTCardNetworkUnknown;
    }
    return self;
}

- (UIFont *)regularFontOfSize:(CGFloat)size {
    if (self.fontFamily) {
        UIFont *font = [UIFont fontWithName:self.fontFamily size:size];
        if (font) return font;
    }
    return [UIFont systemFontOfSize:size];
}

- (UIFont *)boldFontOfSize:(CGFloat)size {
    if (self.boldFontFamily) {
        UIFont *font = [UIFont fontWithName:self.boldFontFamily size:size];
        if (font) return font;
    }
    if (self.fontFamily) {
        UIFont *font = [UIFont fontWithName:self.fontFamily size:size];
        if (font) return font;
    }
    return [UIFont boldSystemFontOfSize:size];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.title = @"Card Details";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self
        action:@selector(cancelTapped)];

    // Fields (borderless — container provides the visual grouping)
    self.cardNumberField = [self makeField:@"Card Number" keyboard:UIKeyboardTypeNumberPad secure:NO];
    [self.cardNumberField addTarget:self action:@selector(cardNumberChanged:) forControlEvents:UIControlEventEditingChanged];

    // Card type badge as right accessory of card number field
    self.cardTypeBadge = [[UILabel alloc] initWithFrame:CGRectMake(8, 15, 58, 22)];
    self.cardTypeBadge.font = [self boldFontOfSize:11];
    self.cardTypeBadge.textColor = [UIColor whiteColor];
    self.cardTypeBadge.textAlignment = NSTextAlignmentCenter;
    self.cardTypeBadge.layer.cornerRadius = 5;
    self.cardTypeBadge.layer.masksToBounds = YES;
    self.cardTypeBadge.hidden = YES;
    UIView *badgeWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 74, 52)];
    [badgeWrapper addSubview:self.cardTypeBadge];
    self.cardNumberField.rightView = badgeWrapper;
    self.cardNumberField.rightViewMode = UITextFieldViewModeAlways;

    self.expiryField = [self makeField:@"MM / YY" keyboard:UIKeyboardTypeNumberPad secure:NO];
    self.cvvField    = [self makeField:@"CVV"     keyboard:UIKeyboardTypeNumberPad secure:YES];
    [self.expiryField addTarget:self action:@selector(expiryChanged:) forControlEvents:UIControlEventEditingChanged];

    // Grouped container
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    container.layer.cornerRadius = 12;
    container.layer.masksToBounds = YES;
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *hSep = [[UIView alloc] init]; // horizontal separator between card number and bottom row
    hSep.backgroundColor = [UIColor separatorColor];
    hSep.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *vSep = [[UIView alloc] init]; // vertical separator between expiry and CVV
    vSep.backgroundColor = [UIColor separatorColor];
    vSep.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:self.cardNumberField];
    [container addSubview:hSep];
    [container addSubview:self.expiryField];
    [container addSubview:vSep];
    [container addSubview:self.cvvField];

    // Submit button
    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submitButton setTitle:@"Add Card" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [self boldFontOfSize:17];
    self.submitButton.layer.cornerRadius = 14;
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];

    // Activity indicator inside the submit button
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.color = [UIColor whiteColor];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.submitButton addSubview:self.activityIndicator];

    [self.view addSubview:container];
    [self.view addSubview:self.submitButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    CGFloat fieldHeight = 52;

    [NSLayoutConstraint activateConstraints:@[
        // Container
        [container.topAnchor constraintEqualToAnchor:safe.topAnchor constant:24],
        [container.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [container.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],

        // Card number row
        [self.cardNumberField.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.cardNumberField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.cardNumberField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.cardNumberField.heightAnchor constraintEqualToConstant:fieldHeight],

        // Horizontal separator
        [hSep.topAnchor constraintEqualToAnchor:self.cardNumberField.bottomAnchor],
        [hSep.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [hSep.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [hSep.heightAnchor constraintEqualToConstant:0.5],

        // Expiry field (left half)
        [self.expiryField.topAnchor constraintEqualToAnchor:hSep.bottomAnchor],
        [self.expiryField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.expiryField.widthAnchor constraintEqualToAnchor:container.widthAnchor multiplier:0.5],
        [self.expiryField.heightAnchor constraintEqualToConstant:fieldHeight],
        [self.expiryField.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        // Vertical separator
        [vSep.topAnchor constraintEqualToAnchor:hSep.bottomAnchor constant:12],
        [vSep.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12],
        [vSep.leadingAnchor constraintEqualToAnchor:self.expiryField.trailingAnchor],
        [vSep.widthAnchor constraintEqualToConstant:0.5],

        // CVV field (right half)
        [self.cvvField.topAnchor constraintEqualToAnchor:hSep.bottomAnchor],
        [self.cvvField.leadingAnchor constraintEqualToAnchor:vSep.trailingAnchor],
        [self.cvvField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.cvvField.heightAnchor constraintEqualToConstant:fieldHeight],

        // Submit button
        [self.submitButton.topAnchor constraintEqualToAnchor:container.bottomAnchor constant:24],
        [self.submitButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.submitButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.submitButton.heightAnchor constraintEqualToConstant:56],

        // Spinner inside submit button
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.submitButton.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.submitButton.centerYAnchor],
    ]];
}

- (UITextField *)makeField:(NSString *)placeholder keyboard:(UIKeyboardType)keyboard secure:(BOOL)secure {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.keyboardType = keyboard;
    field.borderStyle = UITextBorderStyleNone;
    field.font = [self regularFontOfSize:16];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.secureTextEntry = secure;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.delegate = self;

    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
    field.leftView = leftPad;
    field.leftViewMode = UITextFieldViewModeAlways;

    return field;
}

#pragma mark - Card Network

- (RNBTCardNetwork)detectNetworkFromDigits:(NSString *)digits {
    if (digits.length == 0) return RNBTCardNetworkUnknown;
    if ([digits hasPrefix:@"4"]) return RNBTCardNetworkVisa;
    if (digits.length >= 2) {
        int p2 = [[digits substringToIndex:2] intValue];
        if (p2 == 34 || p2 == 37) return RNBTCardNetworkAmex;
        if (p2 >= 51 && p2 <= 55) return RNBTCardNetworkMastercard;
        if (p2 == 35) return RNBTCardNetworkJCB;
        if (p2 == 36 || p2 == 38) return RNBTCardNetworkDiners;
    }
    if (digits.length >= 4) {
        int p4 = [[digits substringToIndex:4] intValue];
        if (p4 >= 2221 && p4 <= 2720) return RNBTCardNetworkMastercard;
        if (p4 == 6011) return RNBTCardNetworkDiscover;
        if (p4 >= 6440 && p4 <= 6559) return RNBTCardNetworkDiscover;
        if (p4 >= 3000 && p4 <= 3059) return RNBTCardNetworkDiners;
    }
    if (digits.length >= 3 && [[digits substringToIndex:3] intValue] >= 622) return RNBTCardNetworkDiscover;
    return RNBTCardNetworkUnknown;
}

- (NSString *)networkName:(RNBTCardNetwork)network {
    switch (network) {
        case RNBTCardNetworkVisa:        return @"VISA";
        case RNBTCardNetworkMastercard:  return @"MC";
        case RNBTCardNetworkAmex:        return @"AMEX";
        case RNBTCardNetworkDiscover:    return @"DISC";
        case RNBTCardNetworkJCB:         return @"JCB";
        case RNBTCardNetworkDiners:      return @"DINERS";
        default:                         return @"";
    }
}

- (UIColor *)networkColor:(RNBTCardNetwork)network {
    switch (network) {
        case RNBTCardNetworkVisa:        return [UIColor colorWithRed:0.10 green:0.12 blue:0.44 alpha:1.0];
        case RNBTCardNetworkMastercard:  return [UIColor colorWithRed:0.92 green:0.00 blue:0.11 alpha:1.0];
        case RNBTCardNetworkAmex:        return [UIColor colorWithRed:0.18 green:0.47 blue:0.74 alpha:1.0];
        case RNBTCardNetworkDiscover:    return [UIColor colorWithRed:1.00 green:0.40 blue:0.00 alpha:1.0];
        case RNBTCardNetworkJCB:         return [UIColor colorWithRed:0.00 green:0.45 blue:0.18 alpha:1.0];
        case RNBTCardNetworkDiners:      return [UIColor colorWithRed:0.40 green:0.40 blue:0.40 alpha:1.0];
        default:                         return [UIColor systemGrayColor];
    }
}

- (NSArray<NSNumber *> *)groupsForNetwork:(RNBTCardNetwork)network {
    if (network == RNBTCardNetworkAmex)   return @[@4, @6, @5];
    if (network == RNBTCardNetworkDiners) return @[@4, @6, @4];
    return @[@4, @4, @4, @4];
}

- (NSUInteger)maxDigitsForNetwork:(RNBTCardNetwork)network {
    if (network == RNBTCardNetworkAmex)   return 15;
    if (network == RNBTCardNetworkDiners) return 14;
    return 16;
}

- (NSString *)formatCardDigits:(NSString *)digits network:(RNBTCardNetwork)network {
    NSMutableString *result = [NSMutableString string];
    NSUInteger pos = 0;
    for (NSNumber *len in [self groupsForNetwork:network]) {
        NSUInteger groupLen = len.unsignedIntegerValue;
        if (pos >= digits.length) break;
        NSUInteger end = MIN(pos + groupLen, digits.length);
        if (result.length > 0) [result appendString:@" "];
        [result appendString:[digits substringWithRange:NSMakeRange(pos, end - pos)]];
        pos = end;
    }
    return result;
}

#pragma mark - Text Field Callbacks

- (void)cardNumberChanged:(UITextField *)field {
    NSString *digits = [[field.text componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];

    RNBTCardNetwork network = [self detectNetworkFromDigits:digits];
    self.detectedCardNetwork = network;

    if (network != RNBTCardNetworkUnknown) {
        self.cardTypeBadge.text = [self networkName:network];
        self.cardTypeBadge.backgroundColor = [self networkColor:network];
        self.cardTypeBadge.hidden = NO;
    } else {
        self.cardTypeBadge.hidden = YES;
    }

    NSUInteger maxDigits = [self maxDigitsForNetwork:network];
    if (digits.length > maxDigits) digits = [digits substringToIndex:maxDigits];
    field.text = [self formatCardDigits:digits network:network];

    self.cvvField.placeholder = (network == RNBTCardNetworkAmex) ? @"CVV (4)" : @"CVV";
}

- (void)expiryChanged:(UITextField *)field {
    NSString *digits = [[field.text componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];
    if (digits.length > 4) digits = [digits substringToIndex:4];
    field.text = digits.length >= 3
        ? [NSString stringWithFormat:@"%@ / %@", [digits substringToIndex:2], [digits substringFromIndex:2]]
        : digits;
}

#pragma mark - Actions

- (void)cancelTapped {
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (weakSelf.onCancel) weakSelf.onCancel();
    }];
}

- (void)submitTapped {
    NSString *digits = [[self.cardNumberField.text componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];
    NSString *expiry = [self.expiryField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *cvv    = self.cvvField.text;

    if (digits.length < 13) {
        [self showError:@"Please enter a valid card number."];
        return;
    }

    NSArray<NSString *> *parts = [expiry componentsSeparatedByString:@"/"];
    if (parts.count != 2) {
        [self showError:@"Please enter a valid expiry date (MM / YY)."];
        return;
    }
    NSInteger month = [parts[0] integerValue];
    NSString *yearStr = parts[1].length == 2
        ? [NSString stringWithFormat:@"20%@", parts[1]]
        : parts[1];
    NSInteger year = [yearStr integerValue];

    if (month < 1 || month > 12) {
        [self showError:@"Please enter a valid expiry month."];
        return;
    }
    NSDateComponents *now = [[NSCalendar currentCalendar]
        components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:[NSDate date]];
    if (year < now.year || (year == now.year && month < now.month)) {
        [self showError:@"This card has expired."];
        return;
    }

    NSUInteger cvvMin = (self.detectedCardNetwork == RNBTCardNetworkAmex) ? 4 : 3;
    if (cvv.length < cvvMin) {
        [self showError:[NSString stringWithFormat:@"Please enter a valid CVV (%lu digits).", (unsigned long)cvvMin]];
        return;
    }

    [self.activityIndicator startAnimating];
    [self.submitButton setTitle:@"" forState:UIControlStateNormal];
    self.submitButton.enabled = NO;

    BTCardClient *cardClient = [[BTCardClient alloc] initWithAPIClient:self.apiClient];
    BTCard *card = [[BTCard alloc] init];
    card.number          = digits;
    card.expirationMonth = [NSString stringWithFormat:@"%02ld", (long)month];
    card.expirationYear  = yearStr;
    card.cvv             = cvv;

    __weak typeof(self) weakSelf = self;
    [cardClient tokenizeCard:card completion:^(BTCardNonce * _Nullable nonce, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicator stopAnimating];
            [weakSelf.submitButton setTitle:@"Add Card" forState:UIControlStateNormal];
            weakSelf.submitButton.enabled = YES;
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                if (weakSelf.completion) weakSelf.completion(nonce, error);
            }];
        });
    }];
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Invalid Details"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
