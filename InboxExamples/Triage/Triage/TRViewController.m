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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareForDisplay) name:INNamespacesChangedNotification object:nil];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _messageViews = [NSMutableArray array];
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
    [_messageViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    for (int ii = 0; ii < [[self.threadProvider items] count]; ii++) {
        INThread * thread = [[self.threadProvider items] objectAtIndex: ii];
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


#pragma mark Layout & Animation

- (void)layoutThreads
{
    [UIView animateWithDuration:0.3 delay:0 options: UIViewAnimationOptionAllowUserInteraction animations:^{
        for (int ii = 0; ii < [_messageViews count]; ii ++) {
            TRMessageCardView * item = [_messageViews objectAtIndex: ii];
            CGAffineTransform t = CGAffineTransformMakeRotation(item.angle);
            t = CGAffineTransformTranslate(t, 0, ([_messageViews count] - (ii+1)) * 5);
            [item setTransform: t];
            [item setAlpha: 1];
        }
    } completion:NULL];
}

- (void)insertThread:(id)thread atIndex:(int)index
{
    TRMessageCardView * view = [[TRMessageCardView alloc] initWithFrame: CARD_SIZE];
    [[view exitButton] addTarget:self action:@selector(dismissReadMore:) forControlEvents:UIControlEventTouchUpInside];
    [view setThread: thread];

    if (index < [_messageViews count]) {
        [self.view insertSubview:view belowSubview:[_messageViews objectAtIndex: index]];
        [_messageViews insertObject:view atIndex:index];
    } else {
        [self.view addSubview: view];
        [_messageViews addObject: view];
    }
    
    float displayAngle = (rand() % 1000) / 2000.0 - 0.25;
    [view setAngle: displayAngle];

    // Animate the thread to the center stack from a random direction
    float incomingDist = fmaxf(self.view.frame.size.height, self.view.frame.size.width) + [view frame].size.width;
    float incomingAngle = (rand() % 1000) / 1000.0 * M_PI * 2;
    [view setCenter: CGPointMake(cosf(incomingAngle) * incomingDist, sinf(incomingAngle) * incomingDist)];

    [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [view setCenter: self.view.center];
    } completion: NULL];
    
    // Layout the stack, moving threads down a bit based on their location in the array.
    [self layoutThreads];
}

- (void)removeThread:(id)thread atIndex:(int)index
{
    TRMessageCardView * view = [_messageViews objectAtIndex: index];
    [_messageViews removeObject: view];
    [view removeFromSuperview];
    
    if (index == [_messageViews count]) // item was last object
        [self activateFrontCard];
}

- (void)activateFrontCard
{
    [self layoutThreads];

    [self.view bringSubviewToFront: _saveButton];
    [self.view bringSubviewToFront: _archiveButton];
    
    TRMessageCardView * message = [_messageViews lastObject];
    if (message) {
        [[_messageDragRecognizer view] removeGestureRecognizer: _messageDragRecognizer];
        _messageDragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [message addGestureRecognizer: _messageDragRecognizer];

        [[_messageDTapRecognizer view] removeGestureRecognizer: _messageDTapRecognizer];
        _messageDTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(readMore:)];
        [_messageDTapRecognizer setNumberOfTapsRequired: 2];
        [message addGestureRecognizer: _messageDTapRecognizer];

        [message setTransform: CGAffineTransformIdentity];
        [message setCenter: self.view.center];
    
    } else {
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
    TRMessageCardView * message = (TRMessageCardView*)[tapGesture view];

    // Prevent interaction while the animation is in progress
    [_messageDragRecognizer setEnabled: NO];
    [[message bodyView] setUserInteractionEnabled: YES];
    [[message replyView] setDelegate: self];

    // Remove the message shadow, because it slows down animations
    [[message layer] setShadowOpacity:0];

    [UIView animateWithDuration:0.25 animations:^{
        [_saveButton setAlpha: 0];
        [_archiveButton setAlpha: 0];
        [_messageDismissView setAlpha: 1];
    }];
    
    // Arrange the views so the message can appear over the action buttons
    [self.view bringSubviewToFront: _messageDismissView];
    [self.view bringSubviewToFront: message];
    
    // Expand the card horizontally first, because the width change triggers
    // the web view displaying the content to re-layout. If we do the layout
    // while the card is expanding vertically, it's less noticeable.
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        CGRect expanded = CGRectMake(0, 0, self.view.frame.size.width, (self.view.frame.size.width / message.frame.size.width) * message.frame.size.height);
        expanded.origin.y = message.frame.origin.y - (expanded.size.height - message.frame.size.height) / 2 - 20;
        [message setFrame: expanded];
        
    } completion:^(BOOL finished) {
        [message setShowReplyView: YES];

        float height = [message desiredHeight];
        float heightMax = self.view.frame.size.height - 70;
        height = fminf(height, heightMax);
        
        // Expand the card vertically based on the space it requires
        [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [message setFrame: CGRectMake(0, 20 + (heightMax - height) / 2, self.view.frame.size.width, height)];
        } completion:^(BOOL finished) {
            
            // Animate the shadow back in slowly so nobody notices it was gone.
            [message.layer addAnimation:((^ {
                CABasicAnimation *transition = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
                transition.fromValue = (id)@(0);
                transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                transition.duration = 0.2;
                return transition;
            })()) forKey:@"shadowOpacity"];
            [[message layer] setShadowOpacity:0.2];
        }];
    }];
}

- (IBAction)dismissReadMore:(id)sender
{
    TRMessageCardView * message = [_messageViews lastObject];
    [[message bodyView] setUserInteractionEnabled: NO];
    [[message replyView] resignFirstResponder];

    [_messageDragRecognizer setEnabled: YES];
    [message setShowReplyView: NO];

    [UIView animateWithDuration:0.25 animations:^{
        [_saveButton setAlpha: 1];
        [_archiveButton setAlpha: 1];
        [_messageDismissView setAlpha: 0];
    }];

    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        [message setFrame: CGRectMake((self.view.frame.size.width - CARD_SIZE.size.width) / 2, (self.view.frame.size.height - CARD_SIZE.size.height) / 2, CARD_SIZE.size.width, CARD_SIZE.size.height)];
        
    } completion:^(BOOL finished) {
    }];
}

- (void)drag:(UIPanGestureRecognizer*)panGesture
{
    UIView * message = [panGesture view];
    
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        [_animator removeAllBehaviors];
    }

    CGPoint center = self.view.center;
    CGPoint translation = [panGesture translationInView: self.view];
    
    center.x += translation.x;
    center.y += translation.y;
    
    [message setCenter: center];
    
    UIButton * selectedButton = nil;
    for (UIButton * b in @[_saveButton, _archiveButton]) {
        float selectionDistance = message.frame.size.height / 2 + 40;
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

        if (selectedButton != nil) {
            UIPushBehavior *pushBehavior = [[UIPushBehavior alloc] initWithItems:@[message] mode:UIPushBehaviorModeContinuous];
            [pushBehavior setAngle:atan2f(self.view.center.y - selectedButton.center.y, 0) magnitude: -200];
            [_animator addBehavior: pushBehavior];

            [_messageViews removeObject: message];
            [self activateFrontCard];
            [self resetActionButtonsAfterDelay: 0.3];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [message removeFromSuperview];
            });
            
        } else {
            UISnapBehavior * attachBehavior = nil;
            attachBehavior = [[UISnapBehavior alloc] initWithItem:message snapToPoint:self.view.center];
            [attachBehavior setDamping: 0.6];
            [_animator addBehavior:attachBehavior];

            [self resetActionButtonsAfterDelay: 0];
        }
        
        CGPoint velocity = [panGesture velocityInView: self.view];
        UIPushBehavior *pushBehavior = [[UIPushBehavior alloc] initWithItems:@[message] mode:UIPushBehaviorModeInstantaneous];
        [pushBehavior setAngle:atan2f(velocity.y, velocity.x) magnitude: (sqrtf(powf(velocity.x, 2) + powf(velocity.y, 2)) / 100.0)];
        [_animator addBehavior: pushBehavior];
        [_animator updateItemUsingCurrentState:self.view];
    }
}

- (void)resetActionButtonsAfterDelay:(NSTimeInterval)delay
{
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

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    TRMessageCardView * message = [_messageViews lastObject];
    [UIView animateWithDuration:0.28 animations:^{
        [message setFrame: CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height - 20 - 216)];
    }];
}

- (void)textViewDidChange:(UITextView *)textView
{
    TRMessageCardView * message = [_messageViews lastObject];
    [message setNeedsLayout];
}


@end
