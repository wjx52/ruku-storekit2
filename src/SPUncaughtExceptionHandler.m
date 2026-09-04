#import "SPUncaughtExceptionHandler.h"

static NSUncaughtExceptionHandler *_previousHandler = nil;

static void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"[ruku] Uncaught exception: %@\nReason: %@\nStack: %@",
          exception.name, exception.reason, exception.callStackSymbols);

    if (_previousHandler) {
        _previousHandler(exception);
    }
}

@implementation SPUncaughtExceptionHandler

+ (instancetype)shareInstance {
    static SPUncaughtExceptionHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPUncaughtExceptionHandler alloc] init];
    });
    return instance;
}

- (void)setDefaultHandler {
    _previousHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
}

- (void)getHandler {
    [self setDefaultHandler];
}

@end
