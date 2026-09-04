#import "NewRuKuWindow.h"
#import "NewRuKuView.h"

@implementation NewRuKuWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];

        self.ruKuView = [[NewRuKuView alloc] initWithFrame:CGRectMake(20, 80, frame.size.width - 40, frame.size.height - 160)];
        self.ruKuView.layer.cornerRadius = 10;
        self.ruKuView.clipsToBounds = YES;
        [self addSubview:self.ruKuView];
    }
    return self;
}

@end
