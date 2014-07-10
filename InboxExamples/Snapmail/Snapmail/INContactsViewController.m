//
//  INContactsViewController.m
//  BigSur
//
//  Created by Ben Gotow on 5/5/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INContactsViewController.h"
#import "INAppDelegate.h"


@implementation INContactsViewController

- (id)initForSelectingContactInNamespace:(INNamespace*)ns withCallback:(ContactSelectionBlock)block;
{
    self = [super init];
    if (self) {
		_namespace = ns;
        _contactSelectionCallback = block;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self setTitle: @"Contacts"];

	UIBarButtonItem * left = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelTapped:)];
	[[self navigationItem] setLeftBarButtonItem: left];
    UIBarButtonItem * right = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed: @"send-button.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(sendTapped:)];
    [[self navigationItem] setRightBarButtonItem: right];
    
    [_tableView setRowHeight: 50];
    
	self.contactsProvider = [self.namespace newContactProvider];
    [_contactsProvider setItemSortDescriptors: @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]]];
	[_contactsProvider setDelegate:self];
	[_contactsProvider refresh];
}

- (IBAction)cancelTapped:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)sendTapped:(id)sender
{
    if (!_contactSelectionCallback)
        return;
    
    NSMutableArray * contacts = [NSMutableArray array];
    for (NSIndexPath * ip in [_tableView indexPathsForSelectedRows]) {
        INContact * contact = [[_contactsProvider items] objectAtIndex: [ip row]];
        [contacts addObject: contact];
    }
    _contactSelectionCallback(contacts);
}

#pragma Provider Delegate

- (void)provider:(INModelProvider*)provider dataAltered:(INModelProviderChangeSet *)changeSet
{
	[_tableView beginUpdates];
	[_tableView deleteRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeRemove] withRowAnimation:UITableViewRowAnimationAutomatic];
	[_tableView insertRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeAdd] withRowAnimation:UITableViewRowAnimationAutomatic];
	[_tableView endUpdates];
	[_tableView reloadRowsAtIndexPaths:[changeSet indexPathsFor: INModelProviderChangeUpdate] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)provider:(INModelProvider*)provider dataFetchFailed:(NSError *)error
{
	[[[UIAlertView alloc] initWithTitle:@"Error!" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}

- (void)providerDataChanged:(INModelProvider*)provider
{
	[_tableView reloadData];
}


#pragma mark Table View Data

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[_contactsProvider items] count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell * cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"contact"];
	if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"contact"];
	
	INContact * contact = [[_contactsProvider items] objectAtIndex: [indexPath row]];
    NSString * name = [contact name];
    if ([name length] == 0)
        name = [[[contact email] componentsSeparatedByString:@"@"] firstObject];

    [[cell textLabel] setText: name];
	[[cell detailTextLabel] setText: [contact email]];
    [[cell detailTextLabel] setTextColor: [UIColor grayColor]];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}


@end
