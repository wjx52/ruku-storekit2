#import "NewRuKuView.h"
#import "../InsideAppStore.h"
#import "../RuKuNetworkAPI.h"

@implementation NewRuKuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        [self setUploginView];
        [self setUpfunctionView];
        [self setUpTableView];
    }
    return self;
}

#pragma mark - Setup

- (void)setUploginView {
    CGFloat width = self.bounds.size.width;

    self.loginView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 120)];
    [self addSubview:self.loginView];

    self.usernameLabel = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, width - 40, 40)];
    self.usernameLabel.placeholder = @"账号";
    self.usernameLabel.borderStyle = UITextBorderStyleRoundedRect;
    self.usernameLabel.delegate = self;
    [self.loginView addSubview:self.usernameLabel];

    self.PwdLabel = [[UITextField alloc] initWithFrame:CGRectMake(20, 60, width - 40, 40)];
    self.PwdLabel.placeholder = @"密码";
    self.PwdLabel.secureTextEntry = YES;
    self.PwdLabel.borderStyle = UITextBorderStyleRoundedRect;
    self.PwdLabel.delegate = self;
    [self.loginView addSubview:self.PwdLabel];
}

- (void)setUpfunctionView {
    CGFloat width = self.bounds.size.width;
    CGFloat y = 130;

    UIButton *loginBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    loginBtn.frame = CGRectMake(20, y, (width - 60) / 2, 40);
    [loginBtn setTitle:@"登录" forState:UIControlStateNormal];
    [loginBtn addTarget:self action:@selector(userLogin) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:loginBtn];

    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.frame = CGRectMake(width / 2 + 10, y, (width - 60) / 2, 40);
    [refreshBtn setTitle:@"刷新" forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:refreshBtn];
}

- (void)setUpTableView {
    CGFloat y = 180;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, self.bounds.size.width, self.bounds.size.height - y) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self addSubview:self.tableView];
}

#pragma mark - Actions

- (void)userLogin {
    NSString *username = self.usernameLabel.text;
    NSString *password = self.PwdLabel.text;

    if (username.length == 0 || password.length == 0) {
        return;
    }

    NSDictionary *loginData = @{@"accountName": username, @"password": password};
    [[RuKuNetworkAPI sharedMMNetworkAPI] requestUrl:@"child/login"
                                    withRequestData:loginData
                                     requestsuccess:^(NSDictionary *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *filePath = response[@"filePath"];
            if (filePath) {
                self.filePath = filePath;
            }
            [self refreshData];
        });
    } requestfailure:^(NSDictionary *response) {
        [self uploadFailed];
    } errorFailure:^(NSError *error) {
        [self uploadFailed];
    }];
}

- (void)refreshData {
    [[RuKuNetworkAPI sharedMMNetworkAPI] requestUrl:@"product/receipt/count"
                                    withRequestData:@{}
                                     requestsuccess:^(NSDictionary *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.productArr = response[@"productArr"];
            [self.tableView reloadData];
        });
    } requestfailure:^(NSDictionary *response) {
    } errorFailure:^(NSError *error) {
    }];
}

- (void)uploadFailed {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                      message:@"操作失败"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];

        UIWindow *kw = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) { if (w.isKeyWindow) { kw = w; break; } }
            }
            if (kw) break;
        }
        UIViewController *rootVC = kw.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

- (void)shutDownView {
    [self removeFromSuperview];
}

- (NSArray *)purchaseRecords {
    return self.productArr ?: @[];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.productArr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ProductCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    NSDictionary *item = self.productArr[indexPath.row];
    cell.textLabel.text = item[@"profductName"] ?: item[@"productIdentifier"] ?: @"Unknown";
    cell.detailTextLabel.text = item[@"orderNo"] ?: @"";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.productArr[indexPath.row];
    NSString *productId = item[@"profductId"] ?: item[@"productIdentifier"];
    if (!productId) return;

    // Use InsideAppStore to initiate SK1 purchase
    // On iOS 15+, Tweak.xm hooks intercept addPayment and route through SK2 automatically
    InsideAppStore *store = [InsideAppStore manager];
    store.userfilePatch = self.filePath;
    store.backMassages = ^(NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (info[@"error"]) {
                NSLog(@"[ruku] Purchase failed: %@", info[@"error"]);
                [self uploadFailed];
                return;
            }

            NSLog(@"[ruku] Purchase success: %@", info[@"transactionIdentifier"]);

            if (self.callService) {
                self.callService();
            }
        });
    };
    [store requestProductData:productId];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
    BOOL sk2Available = (NSClassFromString(@"SimpleStoreKit") != nil);
    header.text = [NSString stringWithFormat:@"  商品列表 (StoreKit %@)",
                   sk2Available ? @"2" : @"1"];
    header.font = [UIFont boldSystemFontOfSize:14];
    header.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01;
}

#pragma mark - TextField

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self endEditing:YES];
}

@end
