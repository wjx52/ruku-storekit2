#import "RuKuNetworkAPI.h"
#import "view/NewRuKuWindow.h"
#import "view/NewRuKuView.h"

static NewRuKuWindow *_ruKuWindow = nil;

@implementation RuKuNetworkAPI

+ (instancetype)sharedMMNetworkAPI {
    static RuKuNetworkAPI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RuKuNetworkAPI alloc] init];
    });
    return instance;
}

#pragma mark - Window Management

- (void)showNewRuKuWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_ruKuWindow) return;
        CGRect frame = [UIScreen mainScreen].bounds;
        _ruKuWindow = [[NewRuKuWindow alloc] initWithFrame:frame];
        _ruKuWindow.hidden = NO;

        __weak typeof(self) weakSelf = self;
        _ruKuWindow.ruKuView.callService = ^{
            [weakSelf dissmissNewRuKuWindow];
        };
    });
}

- (void)dissmissNewRuKuWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_ruKuWindow) {
            [_ruKuWindow.ruKuView shutDownView];
            _ruKuWindow.hidden = YES;
            _ruKuWindow = nil;
        }
    });
}

- (void)loadingNewRuKuWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showNewRuKuWindow];
    });
}

#pragma mark - Network

- (void)requestUrl:(NSString *)url
   withRequestData:(NSDictionary *)data
    requestsuccess:(RequestSuccess)success
    requestfailure:(RequestFailure)failure
      errorFailure:(ErrorFailure)errorFailure {

    NSString *baseUrl = @""; // Configure your server base URL
    NSString *fullUrl = [NSString stringWithFormat:@"%@/%@", baseUrl, url];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fullUrl]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    if (data) {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&jsonError];
        if (jsonData) {
            request.HTTPBody = jsonData;
        }
    }

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        if (error) {
            if (errorFailure) errorFailure(error);
            return;
        }

        NSError *parseError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&parseError];
        if (parseError || !responseDict) {
            if (errorFailure) errorFailure(parseError ?: [NSError errorWithDomain:@"RuKu" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]);
            return;
        }

        responseDict = [self processDictionaryIsNSNull:responseDict];

        if (success) success(responseDict);
    }];
    [task resume];
}

#pragma mark - HUD

- (void)showHUD:(NSString *)message {
    [self showHUD:message addView:nil];
}

- (void)showHUD:(NSString *)message addView:(UIView *)view {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *kw = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) { if (w.isKeyWindow) { kw = w; break; } }
            }
            if (kw) break;
        }
        UIView *targetView = view ?: kw;
        if (!targetView) return;

        [self removePlugInHUD];

        self.HUDView = [[UIView alloc] initWithFrame:targetView.bounds];
        self.HUDView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        [targetView addSubview:self.HUDView];

        self.HUD = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        self.HUD.center = self.HUDView.center;
        [self.HUDView addSubview:self.HUD];
        [self.HUD startAnimating];
    });
}

- (void)removePlugInHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.HUD stopAnimating];
        [self.HUDView removeFromSuperview];
        self.HUD = nil;
        self.HUDView = nil;
    });
}

#pragma mark - Utility

- (BOOL)dx_isNullOrNilWithObject:(id)object {
    if (!object || [object isKindOfClass:[NSNull class]]) return YES;
    if ([object isKindOfClass:[NSString class]] && [(NSString *)object length] == 0) return YES;
    return NO;
}

- (NSDictionary *)processDictionaryIsNSNull:(NSDictionary *)dict {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:dict];
    for (NSString *key in dict.allKeys) {
        if ([dict[key] isKindOfClass:[NSNull class]]) {
            result[key] = @"";
        } else if ([dict[key] isKindOfClass:[NSDictionary class]]) {
            result[key] = [self processDictionaryIsNSNull:dict[key]];
        }
    }
    return result;
}

- (void)getGesture {
}

@end
