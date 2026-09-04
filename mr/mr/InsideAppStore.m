#import "InsideAppStore.h"

@implementation InsideAppStore

+ (instancetype)manager {
    static InsideAppStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[InsideAppStore alloc] init];
    });
    return instance;
}

#pragma mark - Product Request (StoreKit 1)

- (void)requestProductData:(NSString *)productId {
    if (![SKPaymentQueue canMakePayments]) {
        if (self.backMassages) {
            self.backMassages(@{@"error": @"Device cannot make payments"});
        }
        return;
    }
    NSSet *productIds = [NSSet setWithObject:productId];
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIds];
    request.delegate = self;
    [request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSArray<SKProduct *> *products = response.products;
    if (products.count > 0) {
        SKProduct *product = products.firstObject;
        self.profductId = product.productIdentifier;
        self.profductName = product.localizedTitle;
        self.currency = [product.priceLocale objectForKey:NSLocaleCurrencyCode];

        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)requestDidFinish:(SKRequest *)request {
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if (self.backMassages) {
        self.backMassages(@{@"error": error.localizedDescription ?: @"Request failed"});
    }
}

#pragma mark - Transaction Observer (StoreKit 1)

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self uploadTransaction:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                if (self.backMassages) {
                    self.backMassages(@{@"error": transaction.error.localizedDescription ?: @"Purchase failed"});
                }
                break;
            case SKPaymentTransactionStateRestored:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
            case SKPaymentTransactionStateDeferred:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray<SKDownload *> *)downloads {
}

- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    return NO;
}

- (void)paymentQueueDidChangeStorefront:(SKPaymentQueue *)queue {
}

- (void)paymentQueue:(SKPaymentQueue *)queue didRevokeEntitlementsForProductIdentifiers:(NSArray<NSString *> *)productIdentifiers {
}

#pragma mark - Upload Transaction

- (void)uploadTransaction:(SKPaymentTransaction *)transaction {
    NSMutableDictionary *transInfo = [NSMutableDictionary dictionary];
    transInfo[@"transactionIdentifier"] = transaction.transactionIdentifier ?: @"";
    transInfo[@"productIdentifier"] = transaction.payment.productIdentifier ?: @"";
    transInfo[@"transactiondate"] = [self getInternetDate:transaction.transactionDate] ?: @"";
    transInfo[@"orderNo"] = transaction.transactionIdentifier ?: @"";
    transInfo[@"profductId"] = self.profductId ?: @"";
    transInfo[@"profductName"] = self.profductName ?: @"";
    transInfo[@"currency"] = self.currency ?: @"";

    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptURL) {
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
        if (receiptData) {
            transInfo[@"receipt"] = [receiptData base64EncodedStringWithOptions:0];
        }
    }

    if (transaction.originalTransaction) {
        transInfo[@"srcOrderNo"] = transaction.originalTransaction.transactionIdentifier ?: @"";
    }

    NSString *filePath = [self userfilePatch];
    if (filePath) {
        NSString *receiptPath = [filePath stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"%@receipt.plist", transaction.transactionIdentifier]];
        [transInfo writeToFile:receiptPath atomically:YES];

        NSString *historyPath = [filePath stringByAppendingPathComponent:@"buyHistory"];
        NSMutableArray *history = [NSMutableArray arrayWithContentsOfFile:historyPath] ?: [NSMutableArray array];
        [history addObject:transInfo];
        [history writeToFile:historyPath atomically:YES];
    }

    if (self.backMassages) {
        self.backMassages(transInfo);
    }
}

#pragma mark - Utility

- (NSString *)getInternetDate:(NSDate *)date {
    if (!date) return @"";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return [formatter stringFromDate:date];
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

@end
