Inbox iOS SDK
======

### **NOTE**: This framework is currently not actively maintained, and may need some TLC. Please feel free to use it and send us a pull request if you fix anything or add a feature.


The InboxKit provides a native interface to the Inbox API, with additional features that make it easy to build full-fledged mail apps for iOS or add the email functionality you need to existing applications.

InboxKit:

- Includes pre-built view controllers for common tasks such as composing email, viewing a list of threads, and authorizing an account.

- Provides native, Objective-C models for threads, messages, contacts, and attachments, and high-level methods for interacting with them.

- Automatically caches data in an SQLite store, allowing you to create applications with great offline behavior with very little effort.

- Allows you to load individual slices of data from the Inbox API, such as a list of threads in the user's inbox with attachments, or create robust email applications that maintain a local cache and sync the user's entire mailbox.

- Comes with kickass sample apps. <links>

<a href="http://inboxapp.github.io/inbox-ios" class="btn btn-primary">Browse the iOS API Reference</a>



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

> Note: Most of the sample apps use Cocoapods. To run one of the demo apps, `cd` to the project directory and run `pod install`. If you haven't used cocoapods before, you'll need to install it by doing `sudo gem install cocoapods`

#### EightBall (Swift)

The EightBall app displays a single unread thread from your Inbox. When you shake the device, it marks it as read and shows another thread. 

#### Triage

The 'Triage' demo app showcases the use of an `INModelProvider` to display threads from your mailbox, and the use of the `INMessageContentView` for displaying message bodies in custom views.

[Video of Triage in Action](https://dl.dropboxusercontent.com/u/4803975/triage_demo.mov)


#### SnapMail

The 'SnapMail' demo is a snapchat-style app that allows you to send and receive photos. Instead of using a custom backend, it uses your inbox—messages with the subject 'New snap from *' are displayed, and sending a snap sends an email to the recipient with the image attached. You can view the image attached to a 'New Snap' email with a snapchat-style peek interaction.

#### SimpleMail

The Simple Mail app displays a list of threads in your Inbox using an `INModelProvider` and allows you to archive them. As we open-source more UI components, SimpleMail will be expanded to allow you to view and compose messages as well.

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

## Authentication
---

If you're building an application against the hosted version of the Inbox API, you need to authenticate your users with Inbox before making API requests. The Inbox SDK for iOS provides convenience methods for moving through the OAuth process, and is very similar to Facebook. Your users click "Sign In" within your app and are directed to www.nylas.com in Safari. After they've signed in to your email, your app receives a callback that includes an authentication token.


1. Add your Inbox App ID to your application's `Info.plist` file as `INAppID`.

2. Add code to your App Delegate to handle authorization callbacks:

```
:::objc
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	return [[INAPIManager shared] handleURL: url];
}
```

3. Find an appropriate place in your application to ask the user to sign into their email account. If you're building a full-fledged mail client, you should ask users to sign in to their email immediately. If your application needs email access for a particular feature, you should prompt users to log in to their email when they access that feature.

4. Call `INAPIManager`'s `authenticateWithEmail:andCompletionBlock:` to begin the login process. This method directs the user to their email provider (Gmail, Exchange, etc.) in Safari to enter their account credentials. When authorization is completed and Inbox has received an auth token, the completion block runs and your application can dismiss login UI and begin displaying mail. If you don't have the user's email address, pass `nil` and Inbox will prompt the user for their email address. 


```
:::objc
NSString * email = @"ben@nylas.com";
[[INAPIManager shared] authenticateWithEmail:email andCompletionBlock:^(BOOL success, NSError *error) {
	if (success)
		// the user approved us to access their account - let's go!
	else if (error)
		[UIAlertView alloc] init....
}];
```

## Displaying Threads
----
Inbox makes it easy to display threads, messages, contacts and other information from the user's mailbox. To fetch Inbox objects, you use an instance of an INModelProvider, which wraps underlying calls to the local cache, the Inbox API, and the Inbox realtime service (coming soon) to provide you with the view you want.

`INModelProvider` is somewhat similar to Core Data's `NSManagedResultsController` and YapDatabase's concept of "Views". The goal is to make it easy to build rich, realtime views of the user's mail and hide the complexity behind retrieving objects, which could come from a cache, be streamed via a socket connection, or fetched via the API.

To display data, your application needs to:

- Create and configure an INModelProvider
- Implement the INModelProviderDelegate protocol

### Creating and Configuring an INModelProvider

Here's an example that shows how to create and configure a model provider for displaying unread threads:

```
:::objc
// fetch a namespace, which represents a particular email address our auth token provides access to.
INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];

// create a new thread provider for displaying threads in that namespace
INThreadProvider * provider = [namespace newThreadProvider];

// configure the provider to display only unread threads using an NSPredicate
[provider setItemFilterPredicate: [NSComparisonPredicate predicateWithFormat: @"ANY tagIDs = %@", INTagIDUnread]];

// configure the provider to sort items by their last message date
[provider setItemSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastMessageDate" ascending:NO]]];

// start monitoring the provider for data
[provider setDelegate: self];
```

Once you've created a provider, you can configure it by providing an NSPredicate. In the example above, we use a predicate to limit our view to threads matching "ANY tagIDs = 'unread'". The Inbox framework uses `NSPredicate` extensively. Under the hood, the predicates are translated into filter parameters for API calls, and into SQL WHERE clauses for retrieving cached data. The predicate is applied to objects as they change, so marking a thread as 'read' automatically triggers that thread to be removed from your provider's displayed set.

Note: `NSCompoundPredicates` are supported, but only AND predicates can be used at this time. Comparison predicates can filter based on a variety of properties, but not all of them. For example, you can't filter messages based on message body. See the documentation for INThread, INMessage, etc. to see which properties you can use in prediates. For advanced filtering, check out the Inbox search API.

Similarly, INModelProvider uses sort descriptors to order the models it provides. You can specify one or more sort descriptors to order data in your view.


### Implementing the INModelProviderDelegate protocol

INModelProvider defines several delegate methods that you should implement to display your view's data. Though you can access the provider's result set directly using the -items method, the items being displayed may change at any time and there may not be items to display immediately after the provider is created. Your view should implement the delegate protocol and update to reflect changes as they happen.

Here's an example of a typical provider delegate implementation:

```
:::objc
/* Called when the items array of the provider has changed substantially. You should refresh your interface completely to reflect the new items array. */

- (void)providerDataChanged:(INModelProvider*)provider
{
    [_tableView reloadData];
}

/* Called when objects have been added, removed, or modified in the items array, usually as a result of new data being fetched from the Inbox API or published on a real-time connection. You may choose to refresh your interface completely or apply the individual changes provided in the changeSet. */

- (void)provider:(INModelProvider*)provider dataAltered:(INModelProviderChangeSet *)changeSet
{
    [_tableView beginUpdates];
    [_tableView deleteRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeRemove] withRowAnimation:UITableViewRowAnimationLeft];
    [_tableView insertRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeAdd] withRowAnimation:UITableViewRowAnimationTop];
    [_tableView endUpdates];
    [_tableView reloadRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeUpdate] withRowAnimation:UITableViewRowAnimationNone];
}

/* Called when an attempt to load data from the Inbox API has failed. If you requested the fetch by calling -refresh on the model provider or modifying the sort descriptors or filter predicate, you may want to display the error provided. */

- (void)provider:(INModelProvider*)provider dataFetchFailed:(NSError *)error
{
    [[[UIAlertView alloc] initWithTitle:@"Error!" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}

/** Called when the provider has fully refresh in response to an explicit refresh request or a change in the item filter predicate or sort descriptors. */
- (void)providerDataFetchCompleted:(INModelProvider*)provider
{
    // hide refresh UI
}
```


