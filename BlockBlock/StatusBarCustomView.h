

#import <Foundation/Foundation.h>



@protocol StatusBarCustomViewDelegate <NSObject>

- (BOOL)isActive;
- (void)menuletClicked;
- (BOOL)isDisabled;

@optional



@end

@interface StatusBarCustomView : NSView

@property (nonatomic, weak) id<StatusBarCustomViewDelegate> delegate;

@end
