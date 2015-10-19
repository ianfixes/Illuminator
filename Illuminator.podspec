
Pod::Spec.new do |s|
  s.name             = "Illuminator"
  s.version          = "1.0.0"
  s.summary          = "ILLUMINATOR - the iOS Automator"
  s.description      = <<-DESC

                       DESC
  s.homepage         = "https://github.com/paypal/Illuminator"
  s.license          = 'Apache License, Version 2.0'
  s.author           = ["Boris Erceg", "Ian Katz"]
  s.source       = { :git => "https://github.com/paypal/Illuminator.git", :tag => s.version.to_s }
  s.platform     = :ios, '8.0'
  s.requires_arc = true
  
  s.resource_bundles = {
    'Illuminator' => ['Pod/Assets/*.png']
  }

  s.ios.frameworks = 'XCTest'
  s.source_files = 'Pod/Bridge/**/*'
  s.source_files = 'Pod/Illuminator/**/*'  

end
