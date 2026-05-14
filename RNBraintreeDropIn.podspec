Pod::Spec.new do |s|
  s.name         = "RNBraintreeDropIn"
  s.version      = "1.1.10"
  s.summary      = "RNBraintreeDropIn"
  s.description  = <<-DESC
                  RNBraintreeDropIn
                   DESC
  s.homepage     = "https://github.com/bamlab/react-native-braintree-payments-drop-in"
  s.license      = "MIT"
  s.author             = { "author" => "lagrange.louis@gmail.com" }
  s.platform     = :ios, "16.0"
  s.source       = { :git => "https://github.com/BradyShober/react-native-braintree-dropin-ui.git", :tag => "master" }
  s.source_files  = "ios/**/*.{h,m}"
  s.resource_bundles = { 'CardNetworks' => ['ios/CardNetworks.xcassets'] }
  s.requires_arc = true
  s.dependency    'React'
  s.dependency    'Braintree/Core',          '~> 7.5'
  s.dependency    'Braintree/Card',          '~> 7.5'
  s.dependency    'Braintree/PayPal',        '~> 7.5'
  s.dependency    'Braintree/ApplePay',      '~> 7.5'
  s.dependency    'Braintree/DataCollector', '~> 7.5'
  s.dependency    'Braintree/Venmo',         '~> 7.5'
end
