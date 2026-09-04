#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "StoreKitBridge.h"

@class RuKuNetworkAPI;

@interface RuKuNetworkAPI : NSObject
+ (instancetype)sharedMMNetworkAPI;
- (void)showNewRuKuWindow;
@end

static NSString *applicationDocumentsDirectory(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

%hook UIWindow

- (void)makeKeyWindow {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Start the unified StoreKit listener (SK2 on iOS 15+, SK1 fallback)
        [[StoreKitBridge shared] startTransactionListener];

        [[StoreKitBridge shared] setTransactionUpdateCallback:^(NSDictionary *info) {
            NSString *filePath = applicationDocumentsDirectory();
            [[StoreKitBridge shared] saveTransactionToLocal:info filePath:filePath];
        }];
    });
}

%end

%hook SKPaymentQueue

- (void)addTransactionObserver:(id)observer {
    if ([[StoreKitBridge shared] useStoreKit2]) {
        NSLog(@"[ruku] SK2 active, skipping SK1 addTransactionObserver");
        return;
    }
    %orig;
}

%end

static void getProduct(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[RuKuNetworkAPI sharedMMNetworkAPI] showNewRuKuWindow];
    });
}

%ctor {
    getProduct();
}
