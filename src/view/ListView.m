#import "ListView.h"
#import "../RuKuNetworkAPI.h"

@implementation ListView

- (instancetype)initWithFrame:(CGRect)frame withRecord:(NSString *)record {
    self = [super initWithFrame:frame];
    if (self) {
        self.records = record;
        self.receiptArr = [NSMutableArray array];
        self.backgroundColor = [UIColor whiteColor];
        [self setUpfunctionView];
        [self setUpTableView];
    }
    return self;
}

- (void)setUpfunctionView {
    CGFloat width = self.bounds.size.width;

    UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    deleteBtn.frame = CGRectMake(20, 10, width - 40, 40);
    [deleteBtn setTitle:@"删除记录" forState:UIControlStateNormal];
    [deleteBtn addTarget:self action:@selector(deleteData) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:deleteBtn];
}

- (void)setUpTableView {
    CGFloat y = 60;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, self.bounds.size.width, self.bounds.size.height - y) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self addSubview:self.tableView];
}

#pragma mark - Actions

- (void)deleteData {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认"
                                                                  message:@"确定删除所有记录?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.receiptArr removeAllObjects];
        [self.tableView reloadData];

        if (self.records) {
            NSString *historyPath = [self.records stringByAppendingPathComponent:@"buyHistory"];
            [[NSFileManager defaultManager] removeItemAtPath:historyPath error:nil];
        }
    }]];

    UIWindow *kw = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in scene.windows) { if (w.isKeyWindow) { kw = w; break; } }
        }
        if (kw) break;
    }
    UIViewController *rootVC = kw.rootViewController;
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getCurrentTimes {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return [formatter stringFromDate:[NSDate date]];
}

- (void)uploadDict:(NSDictionary *)dict {
    if (!dict) return;

    [[RuKuNetworkAPI sharedMMNetworkAPI] requestUrl:@"receipt/import"
                                    withRequestData:dict
                                     requestsuccess:^(NSDictionary *response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"[ruku] Upload receipt success");
        });
    } requestfailure:^(NSDictionary *response) {
        NSLog(@"[ruku] Upload receipt failed");
    } errorFailure:^(NSError *error) {
        NSLog(@"[ruku] Upload receipt error: %@", error.localizedDescription);
    }];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.receiptArr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ReceiptCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    NSDictionary *item = self.receiptArr[indexPath.row];
    cell.textLabel.text = item[@"orderNo"] ?: item[@"transactionIdentifier"] ?: @"";
    cell.detailTextLabel.text = item[@"receiptTimeChar"] ?: item[@"transactiondate"] ?: @"";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.receiptArr[indexPath.row];
    [self uploadDict:item];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
    header.text = @"  交易记录";
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

@end
