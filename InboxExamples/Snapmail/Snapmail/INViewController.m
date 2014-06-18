//
//  INViewController.m
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 Foundry 376, LLC. All rights reserved.
//

#import "INViewController.h"


@implementation INViewController

- (id)init
{
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupProviders) name:INNamespacesChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAfterTasksChange) name:INTaskQueueChangedNotification object:nil];
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
	
	if ([[INAPIManager shared] isAuthenticated]) {
		[self authenticated];
	} else {
		[[INAPIManager shared] authenticateWithAuthToken:@"lol" andCompletionBlock:^(BOOL success, NSError *error) {
			if (error)
				[[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
			if (success)
				[self authenticated];
		}];
	}
}

- (void)authenticated
{
	UIBarButtonItem * capture = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"capture-button.png"] landscapeImagePhone:nil style:UIBarButtonItemStyleBordered target:self action:@selector(startCapture)];
	[self.navigationItem setRightBarButtonItem: capture];
	[_statusLabel setHidden: YES];
	[_tableView setHidden: NO];

	[self setupProviders];
}

- (void)setupProviders
{
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
	if (namespace == nil)
		return;
	if ([_inboxProvider.namespaceID isEqualToString: [namespace ID]])
		return;
		
	[self setTitle: [[[namespace emailAddress] componentsSeparatedByString: @"@"] firstObject]];

	NSPredicate * isSnapPredicate = [NSComparisonPredicate predicateWithFormat:@"subject = \"You've got a new snap!\""];
 	_inboxProvider = [namespace newThreadProvider];
	_inboxProvider.itemSortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"lastMessageDate" ascending:NO]];
    _inboxProvider.itemFilterPredicate = isSnapPredicate;
	_inboxProvider.delegate = self;
	
	UILongPressGestureRecognizer * longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rowLongPress:)];
	[longPress setDelegate: self];
	[_tableView addGestureRecognizer: longPress];
}

- (void)refresh
{
	[_inboxProvider refresh];
}

- (void)refreshAfterTasksChange
{
    if ([[[INAPIManager shared] taskQueue] count] == 0)
        // We've probably finished sending a draft. Refresh now!
        [self refresh];
}

- (NSString*)nameFromParticipants:(NSArray*)participants
{
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];

    for (NSDictionary * participant in participants) {
        if ([participant[@"email"] isEqualToString: [namespace emailAddress]])
            continue;
        if ([participant[@"name"] length] > 0)
            return participant[@"name"];
        else
            return participant[@"email"];
    }
    return nil;
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
	if ([_inboxProvider isRefreshing] == NO)
		[_tableRefreshControl endRefreshing];
}

- (void)provider:(INModelProvider *)provider dataFetchFailed:(NSError *)error
{
	[[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
	[_tableRefreshControl endRefreshing];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _inboxProvider.items.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell * snapCell = [tableView dequeueReusableCellWithIdentifier: @"cell"];
	if (!snapCell) snapCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	
    INThread * thread = [[_inboxProvider items] objectAtIndex: [indexPath row]];
    if ([thread hasTagWithID: INTagIDSent]) {
        [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-sent.png"]];

    } else if ([thread hasTagWithID: INTagIDDraft]) {
        [[snapCell imageView] setImage: [UIImage imageNamed: @"snap-sending.png"]];
    
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
	INThread * thread = [[_inboxProvider items] objectAtIndex: [indexPath row]];
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

		INThread * thread = [[_inboxProvider items] objectAtIndex: [ip row]];
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

	INThread * thread = [[_inboxProvider items] objectAtIndex: [ip row]];
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
