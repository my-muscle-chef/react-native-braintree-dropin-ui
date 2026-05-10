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
@property (nonatomic, copy) BTCardFormCompletion completion;
@property (nonatomic, copy) BTCardFormCancel onCancel;

@property (nonatomic, strong) UITextField *cardNumberField;
@property (nonatomic, strong) UILabel *cardTypeLabel;
@property (nonatomic, strong) UITextField *expiryField;
@property (nonatomic, strong) UITextField *cvvField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, assign) RNBTCardNetwork detectedCardNetwork;

@end

@implementation RNBTCardFormViewController

- (instancetype)initWithAPIClient:(BTAPIClient *)apiClient
                       completion:(BTCardFormCompletion)completion
                         onCancel:(BTCardFormCancel)onCancel {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _apiClient = apiClient;
        _completion = [completion copy];
        _onCancel = [onCancel copy];
        _detectedCardNetwork = RNBTCardNetworkUnknown;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.title = @"Add Card";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self
        action:@selector(cancelTapped)];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Add Card"
        style:UIBarButtonItemStyleDone
        target:self
        action:@selector(submitTapped)];

    // Card number row: [field | card type label]
    self.cardNumberField = [self makeField:@"Card Number" keyboard:UIKeyboardTypeNumberPad secure:NO];
    [self.cardNumberField addTarget:self action:@selector(cardNumberChanged:) forControlEvents:UIControlEventEditingChanged];

    self.cardTypeLabel = [[UILabel alloc] init];
    self.cardTypeLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.cardTypeLabel.textColor = [UIColor secondaryLabelColor];
    self.cardTypeLabel.textAlignment = NSTextAlignmentRight;
    self.cardTypeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardTypeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *cardNumberRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.cardNumberField, self.cardTypeLabel]];
    cardNumberRow.axis = UILayoutConstraintAxisHorizontal;
    cardNumberRow.spacing = 8;
    cardNumberRow.alignment = UIStackViewAlignmentCenter;
    cardNumberRow.translatesAutoresizingMaskIntoConstraints = NO;

    self.expiryField     = [self makeField:@"MM / YY"     keyboard:UIKeyboardTypeNumberPad  secure:NO];
    self.cvvField        = [self makeField:@"CVV"         keyboard:UIKeyboardTypeNumberPad  secure:YES];
    [self.expiryField addTarget:self action:@selector(expiryChanged:) forControlEvents:UIControlEventEditingChanged];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submitButton setTitle:@"Add Card" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.submitButton.layer.cornerRadius = 8;
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        cardNumberRow,
        self.expiryField,
        self.cvvField,
        self.submitButton,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:24],
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],

        [self.submitButton.heightAnchor constraintEqualToConstant:50],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (UITextField *)makeField:(NSString *)placeholder keyboard:(UIKeyboardType)keyboard secure:(BOOL)secure {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.keyboardType = keyboard;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.font = [UIFont systemFontOfSize:16];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.secureTextEntry = secure;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.delegate = self;
    [field.heightAnchor constraintEqualToConstant:48].active = YES;
    return field;
}

#pragma mark - Card Network Detection

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
    if (digits.length >= 3) {
        int p3 = [[digits substringToIndex:3] intValue];
        if (p3 >= 622) return RNBTCardNetworkDiscover;
    }
    return RNBTCardNetworkUnknown;
}

- (NSString *)networkName:(RNBTCardNetwork)network {
    switch (network) {
        case RNBTCardNetworkVisa:        return @"Visa";
        case RNBTCardNetworkMastercard:  return @"Mastercard";
        case RNBTCardNetworkAmex:        return @"Amex";
        case RNBTCardNetworkDiscover:    return @"Discover";
        case RNBTCardNetworkJCB:         return @"JCB";
        case RNBTCardNetworkDiners:      return @"Diners";
        default:                         return @"";
    }
}

// Returns grouping sizes and max digits for a given network.
- (NSArray<NSNumber *> *)groupsForNetwork:(RNBTCardNetwork)network {
    if (network == RNBTCardNetworkAmex)   return @[@4, @6, @5];   // 15 digits
    if (network == RNBTCardNetworkDiners) return @[@4, @6, @4];   // 14 digits
    return @[@4, @4, @4, @4];                                     // 16 digits
}

- (NSUInteger)maxDigitsForNetwork:(RNBTCardNetwork)network {
    if (network == RNBTCardNetworkAmex)   return 15;
    if (network == RNBTCardNetworkDiners) return 14;
    return 16;
}

- (NSString *)formatCardDigits:(NSString *)digits network:(RNBTCardNetwork)network {
    NSArray<NSNumber *> *groups = [self groupsForNetwork:network];
    NSMutableString *result = [NSMutableString string];
    NSUInteger pos = 0;
    for (NSNumber *len in groups) {
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
    self.cardTypeLabel.text = [self networkName:network];

    NSUInteger maxDigits = [self maxDigitsForNetwork:network];
    if (digits.length > maxDigits) digits = [digits substringToIndex:maxDigits];

    NSUInteger cursorOffset = field.text.length; // save rough position
    field.text = [self formatCardDigits:digits network:network];

    // Update CVV max length hint for Amex (4 digits)
    self.cvvField.placeholder = (network == RNBTCardNetworkAmex) ? @"CVV (4 digits)" : @"CVV";
}

- (void)expiryChanged:(UITextField *)field {
    NSString *digits = [[field.text componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                        componentsJoinedByString:@""];
    if (digits.length > 4) digits = [digits substringToIndex:4];
    if (digits.length >= 3) {
        field.text = [NSString stringWithFormat:@"%@ / %@",
                      [digits substringToIndex:2],
                      [digits substringFromIndex:2]];
    } else {
        field.text = digits;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // Block manual edits on formatted fields; we reformat in the callbacks above.
    if (textField == self.cardNumberField || textField == self.expiryField) {
        return YES; // let the change through, callback will reformat
    }
    return YES;
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
    NSString *cvv = self.cvvField.text;

    // Card number
    NSUInteger minDigits = 13;
    if (digits.length < minDigits) {
        [self showError:@"Please enter a valid card number."];
        return;
    }

    // Expiry
    NSArray<NSString *> *parts = [expiry componentsSeparatedByString:@"/"];
    if (parts.count != 2) {
        [self showError:@"Please enter a valid expiry date (MM / YY)."];
        return;
    }
    NSInteger month = [parts[0] integerValue];
    NSString *yearStr = parts[1];
    if (yearStr.length == 2) yearStr = [NSString stringWithFormat:@"20%@", yearStr];
    NSInteger year = [yearStr integerValue];

    if (month < 1 || month > 12) {
        [self showError:@"Please enter a valid expiry month."];
        return;
    }
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *now = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:[NSDate date]];
    if (year < now.year || (year == now.year && month < now.month)) {
        [self showError:@"This card has expired."];
        return;
    }

    // CVV
    NSUInteger cvvMin = (self.detectedCardNetwork == RNBTCardNetworkAmex) ? 4 : 3;
    if (cvv.length < cvvMin) {
        [self showError:[NSString stringWithFormat:@"Please enter a valid CVV (%lu digits).", (unsigned long)cvvMin]];
        return;
    }

    [self.activityIndicator startAnimating];
    self.submitButton.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;

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
            weakSelf.submitButton.enabled = YES;
            weakSelf.navigationItem.rightBarButtonItem.enabled = YES;

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
