//
//  INMessageContentView.m
//  BigSur
//
//  Created by Ben Gotow on 5/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessageContentView.h"
#import "UIView+FrameAdditions.h"


static NSString * messageCSS = @"\
html, body {\
font-family: sans-serif;\
font-size:0.9em;\
margin:0;\
border:0;\
width:%dpx;\
-webkit-text-size-adjust: auto;\
word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;\
}\
.inbox-body {\
padding-top:%dpx;\
padding-left:%dpx;\
padding-bottom:%dpx;\
padding-right:%dpx;\
}\
a {\
color:rgb(%d,%d,%d);\
}\
div {\
max-width:100%%;\
}\
.gmail_extra {\
display:none;\
}\
blockquote, .gmail_quote {\
display:none;\
}\
img {\
max-width: 100%;\
height:auto;\
}";

@implementation INMessageContentView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void)setup
{
	[self setClipsToBounds: YES];
    if (!_tintColor)
        [self setTintColor: [UIColor blueColor]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_contentLoadCompleted) {
        [_textView setFrame: self.bounds];
        [_webView setFrame: self.bounds];
    }
}

- (float)bodyHeight
{
	return [[self scrollView] contentSize].height;
}

- (UIScrollView*)scrollView
{
	if (_webView)
		return [_webView scrollView];
	else
		return _textView;
}

- (void)setFrame:(CGRect)frame
{
    BOOL viewportWidthChange = (frame.size.width != self.frame.size.width);
    [super setFrame: frame];
    if (viewportWidthChange)
        [self setContent: _content];
}

- (void)clearContent
{
    [_webView removeFromSuperview];
    [_webView setDelegate: nil];
    _webView = nil;
    
    [_textView setText: @""];

    _contentLoadCompleted = NO;
}

- (void)setContent:(NSString*)content
{
    _content = content;
    _contentLoadCompleted = NO;
    
    if ([content rangeOfString:@"<[^<]+>" options:NSRegularExpressionSearch].location != NSNotFound)
        [self setContentWebView: content];
    else
        [self setContentTextView: content];
}

- (void)setContentMargin:(UIEdgeInsets)margin
{
    _contentMargin = margin;
}

- (void)setContentWebView:(NSString*)content
{
    [_textView removeFromSuperview];
    _textView = nil;
    
    if (!_webView) {
		/* Note: It's important the web view has a small initial height because it always
		reports it's rendered content size to be at least it's height. We'll make it the
		appropriate size once it's content loads. This height must be > 0 or it won't load 
		at all. */
        _webView = [[UIWebView alloc] initWithFrame: CGRectMake(0, 0, self.bounds.size.width, 5)];
        [_webView setDelegate: self];
        [_webView setTintColor: _tintColor];
        [_webView setScalesPageToFit: YES];
        [_webView setDataDetectorTypes: UIDataDetectorTypeAll];
        [_webView setBackgroundColor:[UIColor whiteColor]];
        [[_webView scrollView] setScrollEnabled: NO];
        [[_webView scrollView] setBackgroundColor:[UIColor whiteColor]];
        [self addSubview: _webView];
    }

    float s = 1.0 / [[UIScreen mainScreen] scale];
	int viewportWidth = self.bounds.size.width;
	
	UIColor * color = [self tintColor];
	if (!color) color = [UIColor blueColor];
    const CGFloat * components = CGColorGetComponents([color CGColor]);
    int tintR = (int)(components[0] * 256);
    int tintG = (int)(components[1] * 256);
    int tintB = (int)(components[2] * 256);
    
	
    NSString * css = [NSString stringWithFormat: messageCSS, viewportWidth, (int)(_contentMargin.top * s), (int)(_contentMargin.left * s), (int)(_contentMargin.bottom * s), (int)(_contentMargin.right * s), tintR, tintG, tintB];
    NSString * html = [NSString stringWithFormat: @"<style>%@</style><meta name=\"viewport\" content=\"width=%d\">\n<div class='inbox-body'>%@</div>", css, viewportWidth, content];
    [html writeToFile:[@"~/Documents/test_email.html" stringByExpandingTildeInPath] atomically:NO encoding:NSUTF8StringEncoding error:nil];
	
	[_webView setAlpha: 0.01];
    [_webView loadHTMLString:html baseURL: _contentBaseURL];
}

- (void)setContentTextView:(NSString*)content
{
    [_webView removeFromSuperview];
    [_webView setDelegate: nil];
    _webView = nil;
    
    if (!_textView) {
        _textView = [[UITextView alloc] initWithFrame: CGRectMake(0, 0, self.bounds.size.width, 1000)];
        [_textView setEditable: NO];
        [_textView setDataDetectorTypes: UIDataDetectorTypeAll];
        [_textView setTintColor: _tintColor];
        [_textView setFont: [UIFont systemFontOfSize: 13]];
        [_textView setTextContainerInset: _contentMargin];
        [_textView setScrollEnabled: NO];
        [self addSubview: _textView];
    }
    
    [_textView setText: content];
    CGSize size = [_textView sizeThatFits: CGSizeMake(self.bounds.size.width, MAXFLOAT)];
    [_textView setFrame: CGRectMake(0, 0, size.width, size.height)];
    
    _contentLoadCompleted = YES;
    if ([self.delegate respondsToSelector: @selector(messageContentViewSizeDetermined:)])
        [self.delegate messageContentViewSizeDetermined: size];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	CGSize s = _webView.scrollView.contentSize;
	[_webView in_setFrameHeight: s.height];
	[_webView setAlpha: 1];

    _contentLoadCompleted = YES;
    
    if ([self.delegate respondsToSelector: @selector(messageContentViewSizeDetermined:)]) {
        [self.delegate messageContentViewSizeDetermined: s];
	}
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	if ((navigationType == UIWebViewNavigationTypeOther) || (navigationType == UIWebViewNavigationTypeReload))
		return YES;
    
	[[UIApplication sharedApplication] openURL: [request URL]];
	return NO;
}

@end
