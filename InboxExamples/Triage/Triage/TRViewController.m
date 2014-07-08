//
//  TRViewController.m
//  Triage
//
//  Created by Ben Gotow on 5/7/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "TRViewController.h"
#import "TRMessageCardView.h"

#define CARD_SIZE CGRectMake(0, 0, 280, 200)

@implementation TRViewController

- (id)init
{
	self = [super init];
	if (self) {
		// Subscribe to the Inbox SDK's INNamespacesChangedNotification so our app responds
		// to changes in authentication. Signing in, signing out, etc.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareForDisplay) name:INNamespacesChangedNotification object:nil];
		
		// Subscribe to UIKeyboardDidChangeFrameNotification so we can shrink the
		// message compose panel accordingly.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameChanged:) name:UIKeyboardDidChangeFrameNotification object:nil];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _cardViews = [NSMutableArray array];
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView: self.view];
    [_animator setDelegate: self];
    
    [_messageDismissView setAlpha: 0];
    [_emptyView setAlpha: 1];
	[_emptyTextLabel setText:@"Make sure the Inbox Sync Engine is running and that http://localhost:5555/n/ returns your synced account info."];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self prepareForDisplay];
}

- (IBAction)refreshTapped:(id)sender
{
    [self prepareForDisplay];
}

- (void)prepareForDisplay
{
    // All threads, messages, etc. live within an Inbox namespace. For this demo, let's
    // just use the first available namespace.
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];

    // Avoid re-creating a thread provider unless our namespace has changed.
    // If we created a new one each time you tapped 'Refresh', the entire thread
    // stack would animate in, instead of just new threads.
    if (!_threadProvider || ([_threadProvider namespaceID] != [namespace ID])) {
        self.threadProvider = [namespace newThreadProvider];

        // Configure our thread provider to display ten messages ordered by date
        // In the future, we could set the itemFilterPredicate to show unread emails only.
        [_threadProvider setItemSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastMessageDate" ascending:NO]]];
        [_threadProvider setItemRange: NSMakeRange(0, 10)];
        [_threadProvider setDelegate:self];
    }
	[_threadProvider refresh];
}


#pragma mark INModelProvider Delegate

- (void)providerDataChanged:(INModelProvider *)provider
{
    /**
     Called when the items array of the provider has changed substantially. We
     refresh your interface completely to reflect the new items array.
     */
    [_cardViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    for (int ii = 0; ii < [[self.threadProvider items] count]; ii++) {
        INThread * thread = [[self.threadProvider items] objectAtIndex: ii];
		
		// To achieve the "piling up" effect, we want to delay the insertion of
		// each card into the UI by a few more milliseconds than the last.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ii * 0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self insertThread:thread atIndex: 100000];
            [self activateFrontCard];
        });
    }
}

- (void)provider:(INModelProvider *)provider dataAltered:(INModelProviderChangeSet *)changeSet
{
    /**
     Called when objects have been added, removed, or modified in the items array, usually
     as a result of new data being fetched from the Inbox API or published on a real-time
     connection. You may choose to refresh your interface completely or apply the individual
     changes provided in the changeSet.
     */
    for (INModelProviderChange * change in [changeSet changes]) {
        if (change.type == INModelProviderChangeAdd)
            [self insertThread:change.item atIndex:change.index];
        if (change.type == INModelProviderChangeRemove)
            [self removeThread:change.item atIndex:change.index];
    }
}

- (void)provider:(INModelProvider *)provider dataFetchFailed:(NSError *)error
{
    // Called when an attempt to load data from the Inbox API has failed.
	[[[UIAlertView alloc] initWithTitle:@"An Error Occurred" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}

- (void)providerDataFetchCompleted:(INModelProvider *)provider
{
}

#pragma mark Performing Actions on Messages

- (void)saveForLater:(INThread*)thread
{
	// this does nothing - the user can see the thread later in their inbox
}

- (void)archive:(INThread*)thread
{
	// archive the thread. This method updates the local cache to reflect the change
	// immediately but may be performed later on the Inbox server if an internet
	// connection is not available.
	[thread archive];
}

#pragma mark Layout & Animation

- (void)layoutThreads
{
	// vertically arrange the cards so cards lower in the stack look like they're
	// beneath the top ones. We use the transform property so that the cards can
	// always animate their positions to self.view.center.
    [UIView animateWithDuration:0.3 delay:0 options: UIViewAnimationOptionAllowUserInteraction animations:^{
        for (int ii = 0; ii < [_cardViews count]; ii ++) {
            TRMessageCardView * card = [_cardViews objectAtIndex: ii];
            CGAffineTransform t = CGAffineTransformMakeRotation(card.angle);
            t = CGAffineTransformTranslate(t, 0, ([_cardViews count] - (ii+1)) * 5);
            [card setTransform: t];
            [card setAlpha: 1];
        }
    } completion:NULL];
}

- (void)insertThread:(id)thread atIndex:(int)index
{
    TRMessageCardView * card = [[TRMessageCardView alloc] initWithFrame: CARD_SIZE];
    [[card exitButton] addTarget:self action:@selector(dismissReadMore:) forControlEvents:UIControlEventTouchUpInside];
    [card setThread: thread];

    if (index < [_cardViews count]) {
        [self.view insertSubview:card belowSubview:[_cardViews objectAtIndex: index]];
        [_cardViews insertObject:card atIndex:index];
    } else {
        [self.view addSubview: card];
        [_cardViews addObject: card];
    }
	
	// Angle the card a bit to create the "stack" effect ala iPhoto
    float displayAngle = (rand() % 1000) / 2000.0 - 0.25;
    [card setAngle: displayAngle];

    // Animate the card to the center from a random direction
    float incomingDist = fmaxf(self.view.frame.size.height, self.view.frame.size.width) + [card frame].size.width;
    float incomingAngle = (rand() % 1000) / 1000.0 * M_PI * 2;
    [card setCenter: CGPointMake(cosf(incomingAngle) * incomingDist, sinf(incomingAngle) * incomingDist)];

    [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [card setCenter: self.view.center];
    } completion: NULL];
    
    // Layout the stack again, moving threads down a bit based on their location in the array.
	// The layout only affects the card's transforms, so it doesn't interfere with the other animation.
    [self layoutThreads];
}

- (void)removeThread:(id)thread atIndex:(int)index
{
	// remove the card from the view and our array
    TRMessageCardView * card = [_cardViews objectAtIndex: index];
    [_cardViews removeObject: card];
    [card removeFromSuperview];
	
	// activate gestures on a new card, if this card was the front card
    if (index == [_cardViews count])
        [self activateFrontCard];
}

- (void)activateFrontCard
{
    [self layoutThreads];

	// bring the buttons to the front so their orange halos appear over the
	// card when you drag it.
    [self.view bringSubviewToFront: _saveButton];
    [self.view bringSubviewToFront: _archiveButton];
	
    TRMessageCardView * card = [_cardViews lastObject];
    if (card) {
		// add double-tap (read more) and drag gestures to the card view
        [[_cardDragRecognizer view] removeGestureRecognizer: _cardDragRecognizer];
        _cardDragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [card addGestureRecognizer: _cardDragRecognizer];

        [[_cardDTapRecognizer view] removeGestureRecognizer: _cardDTapRecognizer];
        _cardDTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(readMore:)];
        [_cardDTapRecognizer setNumberOfTapsRequired: 2];
        [card addGestureRecognizer: _cardDTapRecognizer];

        [card setTransform: CGAffineTransformIdentity];
        [card setCenter: self.view.center];
    
    } else {
		// there is no front card! Tell the user they're out of mail. In the future,
		// we might want to check to see if there are more unread messages in their inbox
		// since we only display the first 10.
		[_emptyTextLabel setText: @"Mission accomplished. You've handled all your unread mail."];
        [UIView animateWithDuration:0.3 animations:^{
            [_emptyView setAlpha: 1];
        }];
        
        [_emptyView setTransform: CGAffineTransformMakeScale(0.5, 0.5)];
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:0 animations:^{
            [_emptyView setTransform: CGAffineTransformIdentity];
        } completion:^(BOOL finished) {
        }];
    }
}

- (void)readMore:(UITapGestureRecognizer*)tapGesture
{
    TRMessageCardView * card = (TRMessageCardView*)[tapGesture view];

    // Prevent interaction while the animation is in progress
    [_cardDragRecognizer setEnabled: NO];
    [[card bodyView] setUserInteractionEnabled: YES];
    [[card replyView] setDelegate: self];

    // Remove the message shadow, because it slows down animations
    [[card layer] setShadowOpacity:0];

    [UIView animateWithDuration:0.25 animations:^{
        [_saveButton setAlpha: 0];
        [_archiveButton setAlpha: 0];
        [_messageDismissView setAlpha: 1];
    }];
    
    // Arrange the views so the message can appear over the action buttons
    [self.view bringSubviewToFront: _messageDismissView];
    [self.view bringSubviewToFront: card];
    
    // Expand the card horizontally first, because the width change triggers
    // the web view displaying the content to re-layout. If we do the layout
    // while the card is expanding vertically, it's less noticeable.
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        CGRect expanded = CGRectMake(0, 0, self.view.frame.size.width, (self.view.frame.size.width / card.frame.size.width) * card.frame.size.height);
        expanded.origin.y = card.frame.origin.y - (expanded.size.height - card.frame.size.height) / 2 - 20;
        [card setFrame: expanded];
        
    } completion:^(BOOL finished) {
        [card setShowReplyView: YES];

        float height = [card desiredHeight];
        float heightMax = self.view.frame.size.height - 70;
        height = fminf(height, heightMax);
        
        // Expand the card vertically based on the space it requires
        [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [card setFrame: CGRectMake(0, 20 + (heightMax - height) / 2, self.view.frame.size.width, height)];
        } completion:^(BOOL finished) {
            
            // Animate the shadow back in slowly so nobody notices it was gone.
            [card.layer addAnimation:((^ {
                CABasicAnimation *transition = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
                transition.fromValue = (id)@(0);
                transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                transition.duration = 0.2;
                return transition;
            })()) forKey:@"shadowOpacity"];
            [[card layer] setShadowOpacity:0.2];
        }];
    }];
}

- (IBAction)dismissReadMore:(id)sender
{
    TRMessageCardView * card = [_cardViews lastObject];
    [[card bodyView] setUserInteractionEnabled: NO];

	// Resign first responder to hide the keyboard if it was visible
    [[card replyView] resignFirstResponder];
	
	// Turn the drag recognizer back on now that we're exiting fullscreen
    [_cardDragRecognizer setEnabled: YES];
    [card setShowReplyView: NO];

	// Animate the top and bottom actions back in. You usually don't want spring
	// damping on view alpha, so we do this in a separate animation block.
    [UIView animateWithDuration:0.25 animations:^{
        [_saveButton setAlpha: 1];
        [_archiveButton setAlpha: 1];
        [_messageDismissView setAlpha: 0];
    }];
	
	// Animate the card down to it's smaller size. We want this animation to be fast,
	// because people are usually less patient when things are disappearing than when
	// they're appearing, so we do it all in one animation.
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        [card setFrame: CGRectMake((self.view.frame.size.width - CARD_SIZE.size.width) / 2, (self.view.frame.size.height - CARD_SIZE.size.height) / 2, CARD_SIZE.size.width, CARD_SIZE.size.height)];
        
    } completion:^(BOOL finished) {
		[_saveButton.superview bringSubviewToFront: _saveButton];
		[_archiveButton.superview bringSubviewToFront: _archiveButton];
    }];
}

- (void)drag:(UIPanGestureRecognizer*)panGesture
{
    TRMessageCardView * card = (TRMessageCardView *)[panGesture view];
    
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        [_animator removeAllBehaviors];
    }
	
	// We know the view always starts in the center, so we compute
	// it's current location by adding the pan gesture's translation
    CGPoint translation = [panGesture translationInView: self.view];
	CGPoint center = self.view.center;
    center.x += translation.x;
    center.y += translation.y;
    [card setCenter: center];

	// Determine the distance to each of the action buttons. We want to animate
	// it's alpha as you get close, and mark it as selected when you reach the
	// threshold distance. Note that the buttons are actually TRMessageActionButtons,
	// which animate the transition to their selected state.
    UIButton * selectedButton = nil;
    for (UIButton * b in @[_saveButton, _archiveButton]) {
        float selectionDistance = card.frame.size.height / 2 + 40;
        float currentDistance = sqrtf(powf(center.x - [b center].x, 2) + powf(center.y - [b center].y, 2));
        
        BOOL selected = (currentDistance < selectionDistance);
        if (!selectedButton) {
            [b setSelected: selected];
            if (selected)
                selectedButton = b;
        }
        [b setAlpha: 1 - 0.5 * ((currentDistance - selectionDistance) / 100.0)];
    }
    
    if (panGesture.state == UIGestureRecognizerStateEnded) {
        [_animator removeAllBehaviors];
		
		// Did the gesture end with a button selected? If so, push the card
		// offscreen in that direction and call an action method.
        if (selectedButton != nil) {
            UIPushBehavior *pushBehavior = [[UIPushBehavior alloc] initWithItems:@[card] mode:UIPushBehaviorModeContinuous];
            [pushBehavior setAngle:atan2f(self.view.center.y - selectedButton.center.y, 0) magnitude: -200];
            [_animator addBehavior: pushBehavior];

            [_cardViews removeObject: card];
            [self activateFrontCard];
            [self resetActionButtonsAfterDelay: 0.3];
			
			if (selectedButton == _archiveButton)
				[self archive: card.thread];
			else if (selectedButton == _saveButton)
				[self saveForLater: card.thread];
			
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [card removeFromSuperview];
            });
            
        } else {
			// The user didn't end the gesture over a button. Use a snap behavior
			// to push the card back to the center of the stack with a nice little
			// twist and bounce.
            UISnapBehavior * attachBehavior = nil;
            attachBehavior = [[UISnapBehavior alloc] initWithItem:card snapToPoint:self.view.center];
            [attachBehavior setDamping: 0.6];
            [_animator addBehavior:attachBehavior];

            [self resetActionButtonsAfterDelay: 0];
        }
		
		// It looks really wrong to release the card and have it fly straight off the screen
		// if you were dragging with significant velocity. To make a more natural animation,
		// apply the current gesture velocity as an instantaneous "push", so the card arcs
		// offscreen as if it has mass.
        CGPoint velocity = [panGesture velocityInView: self.view];
        UIPushBehavior *pushBehavior = [[UIPushBehavior alloc] initWithItems:@[card] mode:UIPushBehaviorModeInstantaneous];
        [pushBehavior setAngle:atan2f(velocity.y, velocity.x) magnitude: (sqrtf(powf(velocity.x, 2) + powf(velocity.y, 2)) / 100.0)];
        [_animator addBehavior: pushBehavior];
        [_animator updateItemUsingCurrentState:self.view];
    }
}

- (void)resetActionButtonsAfterDelay:(NSTimeInterval)delay
{
	// Animate the buttons back to their rest states. We allow for a delay, because
	// these may need to appear after an animation has finished.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.4 animations:^{
            for (UIButton * b in @[_saveButton, _archiveButton]) {
                [b setAlpha: 0.5];
                [b setSelected: NO];
            }
        }];
    });
}

#pragma mark Text View Delegate

- (void)keyboardFrameChanged:(NSNotification *)notif
{
	CGRect frame = [[[notif userInfo] objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];

	TRMessageCardView * card = [_cardViews lastObject];
	[UIView animateWithDuration:0.28 animations:^{
		[card setFrame: CGRectMake(0, 20, self.view.frame.size.width, frame.origin.y - 20)];
	}];
}

- (void)textViewDidChange:(UITextView *)textView
{
    TRMessageCardView * card = [_cardViews lastObject];
    [card setNeedsLayout];
}


@end
