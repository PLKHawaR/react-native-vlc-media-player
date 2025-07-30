Pod::Spec.new do |s|
  s.name         = "react-native-vlc-media-player"
  s.version      = "1.0.38"
  s.summary      = "VLC player"
  s.requires_arc = true
  s.author       = { 'roshan.milinda' => 'rmilinda@gmail.com' }
  s.license      = 'MIT'
  s.homepage     = 'https://github.com/PLKHawaR/react-native-vlc-media-player'
  s.source       = { :git => "https://github.com/PLKHawaR/react-native-vlc-media-player" }
  s.source_files = 'ios/RCTVLCPlayer/*.{framework,h,m,swift}'
  s.ios.deployment_target = "8.4"
  s.tvos.deployment_target = "10.2"
  s.static_framework = true
  s.dependency 'React'
  # s.ios.dependency 'MobileVLCKit', '3.6.0'
  s.tvos.dependency 'TVVLCKit', '3.5.1'
  s.vendored_frameworks = 'VLCKit.framework'
end
