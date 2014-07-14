//
//  SMInboxTableViewController.m
//  SimpleMail
//
//  Created by Ben Gotow on 7/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "SMInboxTableViewController.h"
#import "SMThreadTableViewCell.h"

@implementation SMInboxTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	[self.navigationItem setLeftBarButtonItem: self.editButtonItem];
	[self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];

	[[INAPIManager shared] authenticateWithAuthToken:@"no-open-source-auth" andCompletionBlock:^(BOOL success, NSError *error) {
		if (error) {
			[[[UIAlertView alloc] initWithTitle:@"Auth Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
			return;
		}
		
		INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
		self.threadProvider = [namespace newThreadProvider];
		self.threadProvider.itemSortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastMessageDate" ascending:NO]];
		self.threadProvider.itemRange = NSMakeRange(0, 100);
		self.threadProvider.delegate = self;
	}];

}

- (void)refresh
{
	[self.threadProvider refresh];
}

#pragma mark - INModelProvider delegate

/**
 Called when the items array of the provider has changed substantially. You should
 refresh your interface completely to reflect the new items array.
 @param provider The INModelProvider instance that has changed.
 */
- (void)providerDataChanged:(INModelProvider*)provider
{
	[self.tableView reloadData];
}

/**
 Called when objects have been added, removed, or modified in the items array, usually
 as a result of new data being fetched from the Inbox API or published on a real-time
 connection. You may choose to refresh your interface completely or apply the individual
 changes provided in the changeSet.
 
 @param provider The INModelProvider instance that has been altered.
 @param changeSet The set of items and indexes that have been modified.
 */
- (void)provider:(INModelProvider*)provider dataAltered:(INModelProviderChangeSet *)changeSet
{
	[self.tableView beginUpdates];
	[self.tableView deleteRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeRemove] withRowAnimation:UITableViewRowAnimationAutomatic];
	[self.tableView insertRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeAdd] withRowAnimation:UITableViewRowAnimationAutomatic];
	[self.tableView reloadRowsAtIndexPaths:[changeSet indexPathsFor:INModelProviderChangeUpdate] withRowAnimation:UITableViewRowAnimationAutomatic];
	[self.tableView endUpdates];
}

/**
 Called when an attempt to load data from the Inbox API has failed. If you requested
 the fetch by calling -refresh on the model provider or modifying the sort descriptors
 or filter predicate, you may want to display the error provided.
 
 @param provider The INModelProvider instance.
 @param error The error, with a display-ready message in -localizedDescription.
 */
- (void)provider:(INModelProvider*)provider dataFetchFailed:(NSError *)error
{
	[[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
	[self.refreshControl endRefreshing];
}

/**
 Called when the provider has fully refresh in response to an explicit refresh request
 or a change in the item filter predicate or sort descriptors.
 
 @param provider The INModelProvider instance that completed its fetch.
 */
- (void)providerDataFetchCompleted:(INModelProvider*)provider
{
	[self.refreshControl endRefreshing];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.threadProvider items] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMThreadTableViewCell * cell = (SMThreadTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"ThreadCell" forIndexPath:indexPath];
	INThread * thread = [[self.threadProvider items] objectAtIndex: indexPath.row];

	[cell setThread: thread];

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return @"Archive";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	
	INThread * thread = [[self.threadProvider items] objectAtIndex: indexPath.row];
	[thread archive];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
}

@end
