Pod::Spec.new do |s|
  s.name         = "RNBraintreeDropIn"
  s.version      = "1.0.0"
  s.summary      = "RNBraintreeDropIn"
  s.description  = <<-DESC
                  RNBraintreeDropIn
                   DESC
  s.homepage     = "https://github.com/my-muscle-chef/react-native-braintree-payments-drop-in"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "../LICENSE" }
  s.author             = { "author" => "lagrange.louis@gmail.com" }
  s.platform     = :ios, "12.0"
  s.source       = { :git => "https://github.com/my-muscle-chef/react-native-braintree-dropin-ui.git", :tag => "master" }
  s.source_files  = "*.{h,m}"
  s.requires_arc = true
  s.dependency    'React'
  s.dependency    'Braintree'
  s.dependency    'BraintreeDropIn'
  s.dependency    'Braintree/DataCollector'
  s.dependency    "Braintree/ApplePay", "~> 5.12"
  s.dependency    "Braintree/Card", "~> 5.12"
  s.dependency    "Braintree/Core", "~> 5.12"
  s.dependency    "Braintree/UnionPay", "~> 5.12"
  s.dependency    "Braintree/PayPal", "~> 5.12"
  s.dependency    "Braintree/ThreeDSecure", "~> 5.12"
  s.dependency    "Braintree/Venmo", "~> 5.12"
end
