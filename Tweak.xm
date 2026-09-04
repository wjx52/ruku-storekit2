#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

// Forward declare SimpleStoreKit (loaded from mr_sw.dylib at runtime)
@interface SimpleStoreKit : NSObject
- (void)purchaseWithProductID:(NSString *)productID completion:(void(^)(BOOL success))completion;
- (void)restorePurchasesWithCompletion:(void(^)(BOOL success))completion;
@end

// ObserverItem -- stores original SK1 observer info
@interface ObserverItem : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, weak) id<SKPaymentTransactionObserver> observer;
@end
@implementation ObserverItem
@end

static NSMutableArray<ObserverItem *> *observerItems = nil;
static SimpleStoreKit *_storeKit2 = nil;
static BOOL _sk2Available = NO;

static SimpleStoreKit *getStoreKit2(void) {
    if (!_storeKit2) {
        if (@available(iOS 15.0, *)) {
            Class cls = NSClassFromString(@"SimpleStoreKit");
            if (cls) {
                _storeKit2 = [[cls alloc] init];
                _sk2Available = YES;
            }
        }
    }
    return _storeKit2;
}

// ClassTool -- singleton bridge between SK1 and SK2
@interface ClassTool : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>
+ (instancetype)getInstance;
- (void)initData;
- (void)setP:(SKProduct *)product;
@end

@implementation ClassTool {
    SKProduct *_currentProduct;
}

+ (instancetype)getInstance {
    static ClassTool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ClassTool alloc] init];
        observerItems = [NSMutableArray array];
    });
    return instance;
}

- (void)initData {
    getStoreKit2();
}

- (void)setP:(SKProduct *)product {
    _currentProduct = product;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count > 0) {
        _currentProduct = response.products.firstObject;
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                // Notify stored observers
                for (ObserverItem *item in observerItems) {
                    if (item.observer && [item.observer respondsToSelector:@selector(paymentQueue:updatedTransactions:)]) {
                        [item.observer paymentQueue:queue updatedTransactions:@[transaction]];
                    }
                }
                break;
            case SKPaymentTransactionStateFailed:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

- (void)onMessage:(NSString *)message {
    NSLog(@"[ruku] ClassTool message: %@", message);
}

@end

// === HOOKS ===

%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
    if (_sk2Available) {
        NSString *productID = payment.productIdentifier;
        NSLog(@"[ruku] SK2 intercepting addPayment for: %@", productID);

        SimpleStoreKit *sk2 = getStoreKit2();
        [sk2 purchaseWithProductID:productID completion:^(BOOL success) {
            NSLog(@"[ruku] SK2 purchase result: %@", success ? @"success" : @"failed");
            if (!success) {
                // Fallback to SK1
                %orig;
            }
        }];
        return;
    }
    %orig;
}

- (void)addTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
    // Store the observer for later notification
    ObserverItem *item = [[ObserverItem alloc] init];
    item.observer = observer;
    [observerItems addObject:item];

    if (_sk2Available) {
        NSLog(@"[ruku] SK2 active, storing observer instead of registering with SK1");
        return;
    }
    %orig;
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    if (_sk2Available) {
        NSLog(@"[ruku] SK2 active, SK1 finishTransaction skipped");
        return;
    }
    %orig;
}

%end

%hook UIWindow

- (void)makeKeyWindow {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[ClassTool getInstance] initData];
    });
}

%end

%ctor {
    [[ClassTool getInstance] initData];
}
