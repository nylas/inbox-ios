Inbox iOS SDK
======
----


#### Using InboxKit via Cocoapods

Cocoapods is a dependency management system for Xcode and is the easiest way to create and maintain projects that have dependencies. You can learn more about Cocoapods in the [CocoaPods Getting Started Guide](http://guides.cocoapods.org/using/getting-started.html).

- Add `pod 'InboxKit'` to your Podfile
- Run `pod install`
- Add `#import "Inbox.h"` to your App's prefix header (.pch file)


#### Using InboxKit as a Framework

The Inbox Xcode project declares two framework targets that you can use in your projects if you're not interested in using Cocoapods.

- **For General Use:** The `Inbox-Mk8` framework target is compatible with iOS 7+ and Xcode 5. It uses the "Real" Framework target template assembled by Karl Stenerud. To build it, [download and install](https://github.com/kstenerud/iOS-Universal-Framework) the "Real" framework template into Xcode. This allows you to make Xcode frameworks, right from the "New Project" menu. Unfortunately, this approach is broken in Xcode 6 and will likely be replaced by Xcode 6's new Cocoa Touch Framework.

- **For Xcode 6 / iOS 8:** The `Inbox` framework target is an **Xcode 6 "Cocoa Touch Framework"**. This means that you need Xcode 6 to compile the framework, and it can only be used in apps that target iOS 8 and above. We anticipate that Xcode 6 will be out of beta before the widespread release of the Inbox hosted service, and plan for this to eventually be the only version of the framework.


#### Documentation

See the [Inbox iOS Documentation](http://inboxapp.com/docs/ios) for getting started guides and the [Inbox API Reference](inboxapp.com/docs/api) for information about Inbox's REST API. Class-level documentation has been compiled with [AppleDoc](http://gentlebytes.com/appledoc/) and published to the [`gh-pages` branch](http://inboxapp.github.com/inbox-ios) of this repository.


#### Testing & Linting

To run tests within Xcode, choose Product > Test from the menu.

To run OCLint, choose the OCLint target and make sure you have OCLint installed. [Download it](http://oclint.org/downloads.html) and follow the [installation instructions](http://docs.oclint.org/en/dev/intro/installation.html) to add it to your $PATH. OCLint is really customizable, and we'll be using it in the future to do static analysis beyond what Xcode's analyzer provides. Check out [this article](http://codeascraft.com/2014/01/15/static-analysis-with-oclint/) for a few examples of what OClint can do.


#### Compiling the Documentation

Xcode DocSet format:

```
appledoc --include ./Documentation/. --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "Inbox App, Inc." --company-id com.inbox.ios -d -n --docset-bundle-id com.inbox.ios  --docset-bundle-name "Inbox iOS SDK Documentation"  --ignore=JSON --docset-copyright 2014 ./Inbox
```

HTML format:

```
appledoc --include ./Documentation/. --no-create-docset --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "Inbox App, Inc." --company-id com.inbox.ios --ignore=JSON ./Inbox
```


#### Recommended Development Tools

The [Charles web development proxy](http://www.charlesproxy.com) makes it easy to inspect network activity while the app is running.

[Navicat for SQLLite](http://www.navicat.com/products/navicat-for-sqlite) allows you to interact with the app's SQLLite cache while the app is running.


<br><br>

## Example Apps
----

> Note: All of the sample apps use Cocoapods. To run one of the demo apps, `cd` to the project directory and run `pod install`. If you haven't used cocoapods before, you'll need to install it by doing `sudo gem install cocoapods`

#### Triage

The 'Triage' demo app showcases the use of an `INModelProvider` to display threads from your mailbox, and the use of the `INMessageContentView` for displaying message bodies in custom views.

[Video of Triage in Action](https://dl.dropboxusercontent.com/u/4803975/triage_demo.mov)


##### SnapMail

The 'SnapMail' demo is a snapchat-style app that allows you to send and receive photos. Instead of using a custom backend, it uses your inbox—messages with the subject 'New snap from *' are displayed, and sending a snap sends an email to the recipient with the image attached. You can view the image attached to a 'New Snap' email with a snapchat-style peek interaction.

##### SimpleMail

The Simple Mail app displays a list of threads in your Inbox and allows you to archive them. As we open-source more UI components, SimpleMail will allow you to view and compose messages as well.


## Core Principles
----

There are several core design principles at the heart of the Inbox iOS SDK.

1. **Observing Model Objects**: In the Inbox SDK, model objects (like the classes for messages and threads) broadcast NSNotifications when they're modified. Controllers (and in some cases views) that display these models should subscribe to them in NSNotificationCenter to refresh UI when changes have occurred. Using the NSNotificationCenter API, you can subscribe to a particular object like this:

	    INContact * contact = <contact being displayed>;

	    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:INModelObjectChangedNotification object:contact];


2. **Uniqued Models**: Only one copy of each model object should exist at any given time. For example, if several emails reference the same contact, they should all hold references to the same instance of INContact. This is important for ensuring that subscribing to a model via NSNotifications works, and that updates to a model are properly propogated through the app.

	This principle is enforced in the model layer using an NSMapTable object cache. When models are fetched from the database or returned from an API call, the app queries the object cache for each object ID. If an object already exists in the object cache, that existing object is updated and returned. If it doesn’t exist in the object cache, it’s added. 

3. **Model Providers**: In the Inbox SDK, you fetch objects (threads, messages, etc.) by creating instances of `INModelProvider` and defining the view you want (for example, unread threads from bill@inboxapp.com). Model providers expose a result set via a simple delegate API and ensure that results are as current as possible.

	Using a model provider is slightly more complicated than issuing a simple API request, but implementing the `INModelProvider` delegate protocol ensures that your application is designed for the kind of real-time, asynchronous updates that users expect of modern mail apps. Right now, `INModelProvider` makes API calls and retrieves objects from a local SQLite cache. In the future, it may connect to Inbox via a socket and stream new results to your app in real time. Implementing the `INModelProvider` delegate protocol ensures that your app will immediately support these future improvements.