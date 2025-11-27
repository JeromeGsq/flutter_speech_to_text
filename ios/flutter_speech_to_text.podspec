#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_speech_to_text.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_speech_to_text'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for real-time speech-to-text conversion.'
  s.description      = <<-DESC
A powerful, easy-to-use Flutter plugin for real-time speech-to-text conversion using native iOS Speech Framework.
                       DESC
  s.homepage         = 'https://github.com/JeromeGsq/flutter_speech_to_text'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Arthur Delbeke' => 'arthur.delbeke.pro@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # Privacy manifest for required permissions
  s.resource_bundles = {'flutter_speech_to_text_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

