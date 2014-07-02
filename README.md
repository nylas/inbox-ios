Inbox iOS SDK
======
----

#### Documentation

See the [Inbox iOS Documentation](http://inboxapp.com/docs/ios) for getting started guides and the [Inbox API Reference](inboxapp.com/docs/api) for information about Inbox's REST API. Class-level documentation has been compiled with [AppleDoc](http://gentlebytes.com/appledoc/) and published to the `gh-pages` branch of this repository.

#### Environment Setup

The Inbox.framework target is an **Xcode 6 "Cocoa Touch Framework"**. This means that you need Xcode 6 to compile the framework. We anticipate that Xcode 6 will be out of beta before the widespread release of the Inbox hosted service.

The Inbox framework and some sample apps use Cocoapods, a dependency management system for iOS apps similiar to npm and rpm. To set up your local development environment, you'll need to install cocoapods and do a pod install:

1. `sudo gem install cocoapods`

2. `cd <project directory>`

3. `pod install`

After Cocoapods has installed dependencies, open the project's .xcworkspace (not the .xcproj). Have fun.


#### Testing & Linting

To run tests within Xcode, choose Product > Test from the menu.

To run OCLint, choose the OCLint target and make sure you have OCLint installed. [Download it](http://oclint.org/downloads.html) and follow the [installation instructions](http://docs.oclint.org/en/dev/intro/installation.html) to add it to your $PATH. OCLint is really customizable, and we'll be using it in the future to do static analysis beyond what Xcode's analyzer provides. Check out [this article](http://codeascraft.com/2014/01/15/static-analysis-with-oclint/) for a few examples of what OClint can do.


#### Compiling the Documentation

Xcode DocSet format:

```
appledoc --include ./Documentation/. --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "InboxApp, Inc." --company-id com.inbox.ios -d -n --docset-bundle-id com.inbox.ios  --docset-bundle-name "PARWorks iOS SDK Documentation"  --ignore=JSON --docset-copyright 2014 ./BigSur
```

HTML format:

```
appledoc --include ./Documentation/. --no-create-docset --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "InboxApp, Inc." --company-id com.inbox.ios --ignore=JSON ./BigSur
```


#### Recommended Development Tools

The [Charles web development proxy](http://www.charlesproxy.com) makes it easy to inspect network activity while the app is running.

[Navicat for SQLLite](http://www.navicat.com/products/navicat-for-sqlite) allows you to interact with the app's SQLLite cache while the app is running.


<br><br>

## Example Apps
----

#### Triage

The 'Triage' demo app showcases the use of an `INModelProvider` to display threads from your mailbox, and the use of the `INMessageContentView` for displaying message bodies in custom views.

<video style="width:320px; height:478px; background-color:gray;">
	<source src="https://raw.githubusercontent.com/inboxapp/inbox-ios/master/InboxExamples/Triage/Documentation/demo.mov">
</video>


##### SnapMail

The 'SnapMail' demo is a snapchat-style app that allows you to send and receive photos. Instead of using a custom backend, it uses your inbox—messages with the subject 'New snap from *' are displayed, and sending a snap sends an email to the recipient with the image attached. You can view the image attached to a 'New Snap' email with a snapchat-style peek interaction.



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