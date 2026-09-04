#import <StoreKit/StoreKit.h>
#import <Foundation/Foundation.h>

typedef void(^PurchaseCallback)(NSDictionary *transactionInfo, NSError *error);

@interface InsideAppStore : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate, SKRequestDelegate>

@property (nonatomic, copy) NSString *userfilePatch;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy) void(^backMassages)(NSDictionary *info);
@property (nonatomic, copy) NSString *profductId;
@property (nonatomic, copy) NSString *profductName;

+ (instancetype)manager;

- (void)requestProductData:(NSString *)productId;
- (void)uploadTransaction:(SKPaymentTransaction *)transaction;
- (NSString *)getInternetDate:(NSDate *)date;

@end
