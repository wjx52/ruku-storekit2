#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class NewRuKuWindow;

typedef void(^RequestSuccess)(NSDictionary *response);
typedef void(^RequestFailure)(NSDictionary *response);
typedef void(^ErrorFailure)(NSError *error);

@interface RuKuNetworkAPI : NSObject

@property (nonatomic, copy) void(^callService)(void);
@property (nonatomic, strong) UIActivityIndicatorView *HUD;
@property (nonatomic, strong) UIView *HUDView;

+ (instancetype)sharedMMNetworkAPI;

- (void)showNewRuKuWindow;
- (void)dissmissNewRuKuWindow;
- (void)loadingNewRuKuWindow;

- (void)requestUrl:(NSString *)url
   withRequestData:(NSDictionary *)data
    requestsuccess:(RequestSuccess)success
    requestfailure:(RequestFailure)failure
      errorFailure:(ErrorFailure)errorFailure;

- (void)showHUD:(NSString *)message;
- (void)showHUD:(NSString *)message addView:(UIView *)view;
- (void)removePlugInHUD;

- (BOOL)dx_isNullOrNilWithObject:(id)object;
- (NSDictionary *)processDictionaryIsNSNull:(NSDictionary *)dict;
- (void)getGesture;

@end
