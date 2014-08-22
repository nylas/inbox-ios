//
//  INViewController.m
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 InboxApp, Inc. All rights reserved.
//

#import "INHomeViewController.h"
#import "INAPIManager.h"

@implementation INHomeViewController

- (id)init
{
	self = [super init];
	if (self) {
        // Listen for changes to available Inbox namespaces. This usually means that the
        // user has logged out or logged in, and we need to update the INModelProvider
        // that is backing our table view.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupThreadProvider) name:INNamespacesChangedNotification object:nil];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[_tableView setHidden: YES];
	[_statusLabel setText: @"Signing in to Inbox..."];
	[_statusLabel setHidden: NO];
	
	_tableRefreshControl = [[UIRefreshControl alloc] init];
	[_tableRefreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
	[_tableView addSubview: _tableRefreshControl];

    // Configure a long press recognizer for the Snapchat-style "peek" interaction
    UILongPressGestureRecognizer * longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rowLongPress:)];
    [longPress setDelegate: self];
    [_tableView addGestureRecognizer: longPress];

    // Bounce out to login to Inbox if necessary
    [self authenticateIfNecessary];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self refresh];
}

- (void)authenticateIfNecessary
{
    if ([[INAPIManager shared] isAuthenticated])
        return [self authenticated];
    
    [[INAPIManager shared] authenticateWithCompletionBlock:^(BOOL success, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Auth Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        }
        if (success) {
            [self authenticated];
        }
    }];
}

- (void)authenticated
{
    // Now that we're authenticated, show the new snap button and the table view
	UIBarButtonItem * newSnap = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"capture-button.png"] landscapeImagePhone:nil style:UIBarButtonItemStyleBordered target:self action:@selector(startCapture)];
	[self.navigationItem setRightBarButtonItem: newSnap];

    UIBarButtonItem * logout = [[UIBarButtonItem alloc] initWithTitle:@"Log Out" style:UIBarButtonItemStyleBordered target:self action:@selector(logout)];
	[self.navigationItem setLeftBarButtonItem: logout];

    [_statusLabel setHidden: YES];
	[_tableView setHidden: NO];

    // Now that we're authenticated we have a set of Inbox namespaces available to us.
    // Create the INThreadProvider that will give us a set of threads to display.
	[self setupThreadProvider];
}

- (void)logout
{
    [[INAPIManager shared] unauthenticate];
    [self authenticateIfNecessary];
}

- (void)setupThreadProvider
{
    // Namespaces are the root object of Inbox - threads, contacts, etc. exist within
    // a namespace, which is typically synonymous with an "account" (though maybe not
    // forever!) For this demo, let's just grab the first namespace we have access to.
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
	if (namespace == nil)
		return;

    // If we already have a provider for this namespace, we don't want to re-create it.
    // This would result in a full refresh of our UI which isn't necessary.
    if ([_threadProvider.namespaceID isEqualToString: [namespace ID]])
		return;
    
    // Show a "username" in the title bar so we know which email account we're using
	[self setTitle: [[[namespace emailAddress] componentsSeparatedByString: @"@"] firstObject]];

    // Create the INThreadProvider that will give us a list of threads to display.
    // Model providers are a core concept of the Inbox platform. Rather than directly
    // query the API for a list of threads, we configure a provider that defines the
    // "view" we're interested in. As that view changes, we receive delegate callbacks
    // so we can update the UI. Model providers pull data from local cache and the API,
    // and will eventually use a socket API to retrieve new data in real-time.

    // Model providers use standard Foundation predicates and sort descriptors. In this
    // case, we want all threads with our "New snap!" subject, and we want them
    // sorted by message date.
    NSPredicate * snapSubjectPredicate = [NSComparisonPredicate predicateWithFormat:@"subject = \"You've got a new snap!\""];
 	_threadProvider = [namespace newThreadProvider];
	_threadProvider.itemSortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"lastMessageDate" ascending:NO]];
    _threadProvider.itemFilterPredicate = snapSubjectPredicate;
	_threadProvider.delegate = self;
}

- (void)refresh
{
    // Tell the thread provider to query the API and give us new data
	[_threadProvider refresh];
}

- (NSString*)nameFromParticipants:(NSArray*)participants
{
    // Each thread provided by Inbox has a list of participants. We want to show
    // the name or email address of the "participant who is not us".
    
    for (NSDictionary * participant in participants) {
        if ([[[INAPIManager shared] namespaceEmailAddresses] containsObject: participant[@"email"]])
            continue;
        if ([participant[@"name"] length] > 0)
            return participant[@"name"];
        else
            return participant[@"email"];
    }
    return @"Yourself";
}

- (void)provider:(INModelProvider *)provider dataAltered:(INModelProviderChangeSet *)changeSet
{
	[_tableView beginUpdates];
	[_tableView deleteRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeRemove assumingSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
	[_tableView insertRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeAdd assumingSection:0] withRowAnimation:UITableViewRowAnimationAutomatic];
	[_tableView endUpdates];
	[_tableView reloadRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeUpdate assumingSection:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)providerDataChanged:(INModelProvider *)provider
{
	[_tableView reloadData];
}

- (void)providerDataFetchCompleted:(INModelProvider *)provider
{
	if ([_threadProvider isRefreshing] == NO)
		[_tableRefreshControl endRefreshing];
}

- (void)provider:(INModelProvider *)provider dataFetchFailed:(NSError *)error
{
	[[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
	[_tableRefreshControl endRefreshing];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _threadProvider.items.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell * snapCell = [tableView dequeueReusableCellWithIdentifier: @"cell"];
	if (!snapCell) snapCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	
    INThread * thread = [[_threadProvider items] objectAtIndex: [indexPath row]];

    if ([thread hasTagWithID: INTagIDDraft]) {
        [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-sending.png"]];
        [[snapCell detailTextLabel] setText: @""];
    
    } else if ([thread hasTagWithID: INTagIDSent]) {
        [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-sent.png"]];
        [[snapCell detailTextLabel] setText: @""];

    } else if ([thread hasTagWithID: INTagIDInbox]) {
        if ([thread hasTagWithID: INTagIDUnread]) {
            [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-unread.png"]];
            [[snapCell detailTextLabel] setText: @"Hold to View"];
        } else {
            [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-read.png"]];
            [[snapCell detailTextLabel] setText: @"Tap to Reply"];
        }
    }
    [[snapCell textLabel] setText: [self nameFromParticipants: [thread participants]]];

	return snapCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	INThread * thread = [[_threadProvider items] objectAtIndex: [indexPath row]];
	if ([thread hasTagWithID: INTagIDUnread] == NO) // tap to reply
		[self startCaptureForThread: thread];
		
	[tableView deselectRowAtIndexPath: indexPath animated:YES];
}

- (void)rowLongPress:(UITapGestureRecognizer*)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateBegan) {
		CGPoint p = [recognizer locationInView: _tableView];
		NSIndexPath * ip = [_tableView indexPathForRowAtPoint: p];

		[_snapController removeFromParentViewController];
		[_snapController.view removeFromSuperview];
		_snapController = nil;

		INThread * thread = [[_threadProvider items] objectAtIndex: [ip row]];
		_snapController = [[INSnapViewController alloc] initWithThread: thread];
		
		[self.navigationController.view addSubview: _snapController.view];
		[self.navigationController addChildViewController: _snapController];
		[_snapController.view setAlpha: 0];
		
		[UIView animateWithDuration:0.3 animations:^{
			[_snapController.view setAlpha: 1];
		}];
		[_snapController.view setTransform: CGAffineTransformMakeScale(0.8, 0.8)];
		[UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			[_snapController.view setTransform: CGAffineTransformMakeScale(1.0, 1.0)];
		} completion:NULL];
	}
	
	if ((recognizer.state == UIGestureRecognizerStateEnded) || (recognizer.state == UIGestureRecognizerStateCancelled)) {
		[self dismissSnapViewController];
	}
}

- (void)dismissSnapViewController
{
    [_snapController viewWillDisappear: YES];
	[UIView animateWithDuration:0.3 animations:^{
		[_snapController.view setAlpha: 0];
		[_snapController.view setTransform: CGAffineTransformMakeScale(0.8, 0.8)];
	} completion:^(BOOL finished) {
		[_snapController removeFromParentViewController];
		[_snapController.view removeFromSuperview];
		_snapController = nil;
	}];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
	CGPoint p = [recognizer locationInView: _tableView];
	NSIndexPath * ip = [_tableView indexPathForRowAtPoint: p];
	if (!ip)
		return NO;

	INThread * thread = [[_threadProvider items] objectAtIndex: [ip row]];
	return ([thread hasTagWithID: INTagIDUnread]);
}

- (void)startCapture
{
	[self startCaptureForThread: nil];
}

- (void)startCaptureForThread:(INThread*)threadOrNil
{
	UIImagePickerController * picker = [[UIImagePickerController alloc] init];

	// Insert the overlay
	self.captureController = [[INCaptureViewController alloc] initWithThread: threadOrNil];
	self.captureController.picker = picker;
	picker.delegate = self.captureController;

	if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
		picker.sourceType = UIImagePickerControllerSourceTypeCamera;
		picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
		picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
		picker.cameraOverlayView = self.captureController.view;
		picker.showsCameraControls = NO;
	} else {
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	}
	picker.navigationBarHidden = YES;
	picker.toolbarHidden = YES;
	
	[self presentViewController:picker animated:NO completion:NULL];
}

@end
