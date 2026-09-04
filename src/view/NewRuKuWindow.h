#import <UIKit/UIKit.h>

@class NewRuKuView;

@interface NewRuKuWindow : UIWindow

@property (nonatomic, strong) NewRuKuView *ruKuView;
@property (nonatomic, strong) NSTimer *timer;

@end
