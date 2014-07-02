#import <UIKit/UIKit.h>

@interface UIView (FrameAdditions)

- (void)in_setFrameY:(float)y;
- (void)in_setFrameX:(float)x;
- (void)in_shiftFrame:(CGPoint)offset;
- (void)in_setFrameOrigin:(CGPoint)origin;
- (void)in_setFrameSize:(CGSize)size;
- (void)in_setFrameCenter:(CGPoint)p;
- (void)in_setFrameWidth:(float)w;
- (void)in_setFrameHeight:(float)h;
- (CGPoint)in_topRight;
- (CGPoint)in_bottomRight;
- (CGPoint)in_bottomLeft;
- (id)viewAncestorOfClass:(Class)klass;

@end
