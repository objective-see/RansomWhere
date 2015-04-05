

#import <Foundation/Foundation.h>



@protocol StatusBarCustomViewDelegate <NSObject>

- (NSString *)activeImageName;
- (NSString *)inactiveImageName;
- (BOOL)isActive;
- (void)menuletClicked;
- (BOOL)isDisabled;

@optional



@end

@interface StatusBarCustomView : NSView

@property (nonatomic, weak) id<StatusBarCustomViewDelegate> delegate;

@end
