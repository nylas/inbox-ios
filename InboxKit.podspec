#
#  Be sure to run `pod spec lint InboxSDK.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "InboxKit"
  s.version      = "0.0.2"
  s.summary      = "The Inbox iOS framework provides a native interface to the Inbox API."
  s.description  = "The Inbox iOS framework provides a native interface to the Inbox API, with additional features that make it easy to build full-fledged mail apps for iOS or add the email functionality you need to existing applications."
  s.homepage     = "https://github.com/inboxapp/inbox-ios"
  s.license      = { :type => "MIT", :file => "LICENSE.md" }
  s.platform     = :ios, "7.0"

  s.author             = { "Ben Gotow" => "ben@inboxapp.com" }
  s.social_media_url   = "http://twitter.com/bengotow"

  s.prefix_header_file = "InboxFramework/Inbox/Inbox-Prefix.pch"

  s.source       = { :git => "https://github.com/inboxapp/inbox-ios.git", :submodules => true, :tag => s.version }
  s.source_files  = "InboxFramework/Submodules/INDependencyNamespacing.h", "InboxFramework/Submodules/FMDB/src/fmdb/*.{h,m}", "InboxFramework/Submodules/AFNetworking/AFNetworking/*.{h,m}", "InboxFramework/Submodules/AFNetworking/UIKit+AFNetworking/*.{h,m}", "InboxFramework/Submodules/PDKeychainBindingsController/PDKeychainBindingsController/*.{h,m}", "InboxFramework/Inbox/*.{h,m}", "InboxFramework/Inbox/**/*.{h,m}", "InboxFramework/InboxUI/**/*.{h,m}"

  s.public_header_files = "InboxFramework/Inbox/*.h", "InboxFramework/Inbox/**/*.h", "InboxFramework/InboxUI/**/*.h"

  s.libraries = "sqlite3"
  s.requires_arc = true

end
