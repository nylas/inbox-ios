//
//  INPlaceholderTextView.h
//  BigSur
//
//  DRAWN FROM http://stackoverflow.com/questions/1328638/placeholder-in-uitextview

#import <UIKit/UIKit.h>

@interface INPlaceholderTextView : UITextView

@property (nonatomic, retain) NSString *placeholder;
@property (nonatomic, retain) UIColor *placeholderColor;

-(void)textChanged:(NSNotification*)notification;


@end
