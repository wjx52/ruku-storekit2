#import <Foundation/Foundation.h>

@interface SPUncaughtExceptionHandler : NSObject

+ (instancetype)shareInstance;
- (void)setDefaultHandler;
- (void)getHandler;

@end
