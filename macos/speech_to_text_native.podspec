#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_speech_to_text.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_speech_to_text'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for real-time speech-to-text conversion.'
  s.description      = <<-DESC
A powerful, easy-to-use Flutter plugin for real-time speech-to-text conversion using native macOS Speech Framework.
                       DESC
  s.homepage         = 'https://github.com/JeromeGsq/flutter_speech_to_text'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Arthur Delbeke' => 'arthur.delbeke.pro@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.swift_version    = '5.0'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

