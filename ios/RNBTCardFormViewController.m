#import "RNBTCardFormViewController.h"
#import "BraintreeDropIn.h"

@interface RNBTCardFormViewController () <UITextFieldDelegate>

@property (nonatomic, strong) BTAPIClient *apiClient;
@property (nonatomic, copy) BTCardFormCompletion completion;
@property (nonatomic, copy) BTCardFormCancel onCancel;

@property (nonatomic, strong) UITextField *cardNumberField;
@property (nonatomic, strong) UITextField *expiryField;
@property (nonatomic, strong) UITextField *cvvField;
@property (nonatomic, strong) UITextField *postalCodeField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

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
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)setupUI {
    self.title = @"Add Card";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self
        action:@selector(cancelTapped)];

    self.cardNumberField  = [self makeField:@"Card Number"  keyboard:UIKeyboardTypeNumberPad];
    self.expiryField      = [self makeField:@"MM / YY"      keyboard:UIKeyboardTypeNumberPad];
    self.cvvField         = [self makeField:@"CVV"          keyboard:UIKeyboardTypeNumberPad];
    self.postalCodeField  = [self makeField:@"Postal Code"  keyboard:UIKeyboardTypeDefault];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submitButton setTitle:@"Add Card" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.submitButton.layer.cornerRadius = 8;
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.cardNumberField,
        self.expiryField,
        self.cvvField,
        self.postalCodeField,
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

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:24],
        [stack.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],

        [self.submitButton.heightAnchor constraintEqualToConstant:50],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (UITextField *)makeField:(NSString *)placeholder keyboard:(UIKeyboardType)keyboard {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.keyboardType = keyboard;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.font = [UIFont systemFontOfSize:16];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.delegate = self;
    [field.heightAnchor constraintEqualToConstant:48].active = YES;
    return field;
}

- (void)cancelTapped {
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (weakSelf.onCancel) weakSelf.onCancel();
    }];
}

- (void)submitTapped {
    NSString *cardNumber = [self.cardNumberField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *expiry     = [self.expiryField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *cvv        = self.cvvField.text;
    NSString *postalCode = self.postalCodeField.text;

    NSArray<NSString *> *expiryParts = [expiry componentsSeparatedByString:@"/"];

    if (cardNumber.length < 13 || expiryParts.count != 2 || cvv.length < 3 || postalCode.length < 1) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Invalid Details"
            message:@"Please fill in all card details correctly."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *expiryMonth = expiryParts[0];
    NSString *expiryYear  = expiryParts[1];
    if (expiryYear.length == 2) {
        expiryYear = [NSString stringWithFormat:@"20%@", expiryYear];
    }

    [self.activityIndicator startAnimating];
    self.submitButton.enabled = NO;

    BTCardClient *cardClient = [[BTCardClient alloc] initWithAPIClient:self.apiClient];
    BTCard *card = [[BTCard alloc] init];
    card.number          = cardNumber;
    card.expirationMonth = expiryMonth;
    card.expirationYear  = expiryYear;
    card.cvv             = cvv;
    card.postalCode      = postalCode;

    __weak typeof(self) weakSelf = self;
    [cardClient tokenizeCard:card completion:^(BTCardNonce * _Nullable nonce, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicator stopAnimating];
            weakSelf.submitButton.enabled = YES;

            [weakSelf dismissViewControllerAnimated:YES completion:^{
                if (weakSelf.completion) weakSelf.completion(nonce, error);
            }];
        });
    }];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField == self.expiryField) {
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSString *digits = [[newText componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
        if (digits.length > 4) return NO;
        if (digits.length >= 3) {
            textField.text = [NSString stringWithFormat:@"%@ / %@",
                [digits substringToIndex:2],
                [digits substringFromIndex:2]];
        } else {
            textField.text = digits;
        }
        return NO;
    }
    return YES;
}

@end
