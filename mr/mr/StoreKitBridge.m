#import "StoreKitBridge.h"
#import "InsideAppStore.h"

#if __has_include("mr-Swift.h")
#import "mr-Swift.h"
#else
@interface StoreKit2Manager : NSObject
@property (class, nonatomic, readonly) StoreKit2Manager *shared;
@property (class, nonatomic, readonly) BOOL isAvailable;
- (void)startTransactionListener;
- (void)stopTransactionListener;
- (void)requestProduct:(NSString *)productId completion:(void(^)(NSDictionary * _Nullable))completion;
- (void)purchaseProduct:(NSString *)productId uuid:(NSString * _Nullable)uuid completion:(void(^)(NSDictionary * _Nullable, NSError * _Nullable))completion;
- (void)restorePurchases;
@property (nonatomic, copy) void(^transactionCallback)(NSDictionary *);
@end
#endif

@interface StoreKitBridge ()
@property (nonatomic, copy) StoreKitTransactionUpdate transactionUpdateCallback;
@property (nonatomic, copy) StoreKitPurchaseCompletion pendingSK1Completion;
@end

@implementation StoreKitBridge

+ (instancetype)shared {
    static StoreKitBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StoreKitBridge alloc] init];
    });
    return instance;
}

- (BOOL)useStoreKit2 {
    if (@available(iOS 15.0, *)) {
        return [StoreKit2Manager isAvailable];
    }
    return NO;
}

#pragma mark - Transaction Listener

- (void)startTransactionListener {
    if (self.useStoreKit2) {
        if (@available(iOS 15.0, *)) {
            StoreKit2Manager *sk2 = [StoreKit2Manager shared];
            __weak typeof(self) weakSelf = self;
            sk2.transactionCallback = ^(NSDictionary *info) {
                if (weakSelf.transactionUpdateCallback) {
                    weakSelf.transactionUpdateCallback(info);
                }
            };
            [sk2 startTransactionListener];
        }
    } else {
        InsideAppStore *sk1 = [InsideAppStore manager];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:sk1];
    }
}

- (void)stopTransactionListener {
    if (self.useStoreKit2) {
        if (@available(iOS 15.0, *)) {
            [[StoreKit2Manager shared] stopTransactionListener];
        }
    } else {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:[InsideAppStore manager]];
    }
}

#pragma mark - Request Product

- (void)requestProduct:(NSString *)productId completion:(StoreKitProductCompletion)completion {
    if (self.useStoreKit2) {
        if (@available(iOS 15.0, *)) {
            [[StoreKit2Manager shared] requestProduct:productId completion:^(NSDictionary * _Nullable info) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(info);
                });
            }];
        }
    } else {
        InsideAppStore *sk1 = [InsideAppStore manager];
        [sk1 requestProductData:productId];
        NSDictionary *info = @{
            @"productIdentifier": productId,
            @"storeKitVersion": @1
        };
        completion(info);
    }
}

#pragma mark - Purchase

- (void)purchaseProduct:(NSString *)productId
                   uuid:(NSString *)uuid
             completion:(StoreKitPurchaseCompletion)completion {
    if (self.useStoreKit2) {
        if (@available(iOS 15.0, *)) {
            [[StoreKit2Manager shared] purchaseProduct:productId uuid:uuid completion:^(NSDictionary * _Nullable info, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(info, error);
                });
            }];
            return;
        }
    }

    // StoreKit 1 fallback
    InsideAppStore *sk1 = [InsideAppStore manager];
    self.pendingSK1Completion = completion;

    __weak typeof(self) weakSelf = self;
    sk1.backMassages = ^(NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            StoreKitBridge *strongSelf = weakSelf;
            if (!strongSelf) return;

            NSMutableDictionary *enriched = [info mutableCopy];
            enriched[@"storeKitVersion"] = @1;

            NSString *errorMsg = info[@"error"];
            if (errorMsg) {
                NSError *error = [NSError errorWithDomain:@"StoreKit1"
                                                     code:-1
                                                 userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                if (strongSelf.pendingSK1Completion) {
                    strongSelf.pendingSK1Completion(nil, error);
                    strongSelf.pendingSK1Completion = nil;
                }
            } else {
                if (strongSelf.pendingSK1Completion) {
                    strongSelf.pendingSK1Completion(enriched, nil);
                    strongSelf.pendingSK1Completion = nil;
                }
            }

            if (strongSelf.transactionUpdateCallback) {
                strongSelf.transactionUpdateCallback(enriched);
            }
        });
    };

    [sk1 requestProductData:productId];
}

#pragma mark - Restore

- (void)restorePurchases {
    if (self.useStoreKit2) {
        if (@available(iOS 15.0, *)) {
            [[StoreKit2Manager shared] restorePurchases];
            return;
        }
    }
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - Callback

- (void)setTransactionUpdateCallback:(StoreKitTransactionUpdate)callback {
    _transactionUpdateCallback = [callback copy];
}

#pragma mark - Local Persistence (shared format)

- (void)saveTransactionToLocal:(NSDictionary *)transInfo filePath:(NSString *)filePath {
    if (!filePath || !transInfo) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        [fm createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *transId = transInfo[@"transactionIdentifier"] ?: transInfo[@"orderNo"] ?: @"unknown";
    NSString *receiptPath = [filePath stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"%@receipt.plist", transId]];
    [transInfo writeToFile:receiptPath atomically:YES];

    NSString *historyPath = [filePath stringByAppendingPathComponent:@"buyHistory"];
    NSMutableArray *history = [NSMutableArray arrayWithContentsOfFile:historyPath] ?: [NSMutableArray array];
    [history addObject:transInfo];
    [history writeToFile:historyPath atomically:YES];
}

@end
