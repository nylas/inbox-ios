bigsur
======

#### Environment Setup

BigSur uses Cocoapods, a dependency management system for iOS apps similiar to npm and rpm. To set up your local development environment, you'll need to install cocoapods and do a pod install:

1. `sudo gem install cocoapods`

2. `cd <project directory>`

3. `pod install`

After Cocoapods has installed dependencies, open the project's .xcworkspace (not the .xcproj). Have fun.

The Inbox Framework is an actual static framework. Unfortunately, Xcode doesn't support building frameworks for the iOS platform out of the box. You can extend Xcode to support framework targets by downloading the repository at [https://github.com/kstenerud/iOS-Universal-Framework](https://github.com/kstenerud/iOS-Universal-Framework), and running the `setup.sh` script found in the Real Framework folder.

***You need to do this before you'll be able to build Inbox.framework***

#### Testing & Linting

To run tests within Xcode, choose Product > Test from the menu.

To run OCLint, choose the OCLint target and make sure you have OCLint installed. [Download it](http://oclint.org/downloads.html) and follow the [installation instructions](http://docs.oclint.org/en/dev/intro/installation.html) to add it to your $PATH. OCLint is really customizable, and we'll be using it in the future to do static analysis beyond what Xcode's analyzer provides. Check out [this article](http://codeascraft.com/2014/01/15/static-analysis-with-oclint/) for a few examples of what OClint can do.

#### Core Principles

There are several core design principles at the heart of BigSur. Before developing on top of the BigSur codebase, you should make sure you understand them! (Otherwise, you'll have a bad time.)

1. **Observing Model Objects**: In BigSur, model objects (like the classes for messages and threads) broadcast NSNotifications when they're modified. Controllers (and in some cases views) that display these models should subscribe to them in NSNotificationCenter to refresh UI when changes have occurred. Using the NSNotificationCenter API, you can subscribe to a particular object like this:

	    INContact * contact = <contact being displayed>;

	    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:INModelObjectChangedNotification object:contact];


2. **Uniqued Models**: Only one copy of each model object should exist at any given time. For example, if several emails reference the same contact, they should all hold references to the same instance of INContact. This is important for ensuring that subscribing to a model via NSNotifications works, and that updates to a model are properly propogated through the app.<br><br>This principle is enforced in the model layer using an NSMapTable object cache. When models are fetched from the database or returned from an API call, the app queries the object cache for each object ID. If an object already exists in the object cache, that existing object is updated and returned. If it doesn’t exist in the object cache, it’s added. 

#### Recommended Development Tools

The [Charles web development proxy](http://www.charlesproxy.com) makes it easy to inspect network activity while the app is running.

[Navicat for SQLLite](http://www.navicat.com/products/navicat-for-sqlite) allows you to interact with the app's SQLLite database while the app is running.

#### Documentation

The BigSur Documentation is compiled with [AppleDoc](http://gentlebytes.com/appledoc/). 

xcode format:

```
appledoc --include ./Documentation/. --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "InboxApp, Inc." --company-id com.inbox.ios -d -n --docset-bundle-id com.inbox.ios  --docset-bundle-name "PARWorks iOS SDK Documentation"  --ignore=JSON --docset-copyright 2014 ./BigSur
```

html format:

```
appledoc --include ./Documentation/. --no-create-docset --index-desc ./Documentation/index-template.txt -o ./ -p "Inbox iOS SDK Documentation" -v 1.0 -c "InboxApp, Inc." --company-id com.inbox.ios --ignore=JSON ./BigSur
```