bigsur
======

#### Environment Setup

BigSur uses Cocoapods, a dependency management system for iOS apps similiar to npm and rpm. To set up your local development environment, you'll need to install cocoapods and do a pod install:

1. `brew install cocoapods`

2. `cd <project directory>`

3. `pod install`

After Cocoapods has installed dependencies, open the project's .xcworkspace (not the .xcproj). Have fun.

#### Testing

The core business logic of BigSur should be extensively tested. To run tests within Xcode, choose Product > Test from the menu.

#### Core Principles

There are several core design principles at the heart of BigSur. Before developing on top of the BigSur codebase, you should make sure you understand them! (Otherwise, you'll have a bad time.)

1. **Observing Model Objects**: In BigSur, model objects (like the classes for messages and threads) broadcast NSNotifications when they're modified. Controllers (and in some cases views) that display these models should subscribe to them in NSNotificationCenter to refresh UI when changes have occurred. Using the NSNotificationCenter API, you can subscribe to a particular object like this:

	    INContact * contact = <contact being displayed>;

	    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:INModelObjectChangedNotification object:contact];


2. **Uniqued Models**: Only one copy of each model object should exist at any given time. For example, if several emails reference the same contact, they should all hold references to the same instance of INContact. This is important for ensuring that subscribing to a model via NSNotifications works, and that updates to a model are properly propogated through the app.<br><br>This principle is enforced in the model layer using an NSMapTable object cache. When models are fetched from the database or returned from an API call, the app queries the object cache for each object ID. If an object already exists in the object cache, that existing object is updated and returned. If it doesn’t exist in the object cache, it’s added. 

#### Recommended Development Tools

The [Charles web development proxy](http://www.charlesproxy.com) makes it easy to inspect network activity while the app is running.

[Navicat for SQLLite](http://www.navicat.com/products/navicat-for-sqlite) allows you to interact with the app's SQLLite database while the app is running.