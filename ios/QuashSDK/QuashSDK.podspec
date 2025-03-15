Pod::Spec.new do |s|
  s.name             = 'QuashSDK'
  s.version          = '0.1.0'
  s.summary          = 'In-app bug reporting and session replay for iOS apps'

  s.description      = <<-DESC
The Quash iOS SDK captures everything you need to start fixing issues right away.
It records crash logs, session replays, network logs, device information, and much more,
ensuring you have all the details at your fingertips.
                       DESC

  s.homepage         = 'https://quashbugs.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Quash' => 'support@quashbugs.com' }
  s.source           = { :git => 'https://github.com/Oscorp-HQ/quash-ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.source_files = 'QuashSDK/Classes/**/*'

  s.resource_bundles = {
    'QuashSDK' => ['QuashSDK/Assets/*.png', 'QuashSDK/Assets/*.xib']
  }

  s.frameworks = 'UIKit', 'Foundation', 'CoreMotion', 'AVFoundation'
  s.dependency 'Firebase/Crashlytics'
  s.dependency 'Firebase/Analytics'
end
