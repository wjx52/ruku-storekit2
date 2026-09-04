#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^StoreKitPurchaseCompletion)(NSDictionary * _Nullable transactionInfo, NSError * _Nullable error);
typedef void(^StoreKitProductCompletion)(NSDictionary * _Nullable productInfo);
typedef void(^StoreKitTransactionUpdate)(NSDictionary *transactionInfo);

@interface StoreKitBridge : NSObject

+ (instancetype)shared;

/// YES if running iOS 15+ and StoreKit 2 is available
@property (nonatomic, readonly) BOOL useStoreKit2;

/// Start listening for transaction updates (call on app launch)
- (void)startTransactionListener;

/// Stop listening for transaction updates
- (void)stopTransactionListener;

/// Request product info, auto-selects SK1 or SK2
- (void)requestProduct:(NSString *)productId completion:(StoreKitProductCompletion)completion;

/// Purchase product, auto-selects SK1 or SK2
/// @param productId Apple product identifier
/// @param uuid Optional UUID for order binding (appAccountToken in SK2, applicationUsername in SK1)
/// @param completion Called with transaction info dict or error
- (void)purchaseProduct:(NSString *)productId
                   uuid:(nullable NSString *)uuid
             completion:(StoreKitPurchaseCompletion)completion;

/// Restore purchases
- (void)restorePurchases;

/// Set callback for background transaction updates (listener)
- (void)setTransactionUpdateCallback:(StoreKitTransactionUpdate)callback;

/// Save transaction info to local receipt plist (same format as SK1 version)
- (void)saveTransactionToLocal:(NSDictionary *)transInfo filePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
