#import <UIKit/UIKit.h>

@interface NewRuKuView : UIView <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, copy) void(^callService)(void);
@property (nonatomic, strong) NSArray *productArr;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *userfilePath;
@property (nonatomic, strong) UITextField *usernameLabel;
@property (nonatomic, strong) UITextField *PwdLabel;
@property (nonatomic, strong) UIView *loginView;
@property (nonatomic, strong) UITableView *tableView;

- (void)setUpTableView;
- (void)setUpfunctionView;
- (void)setUploginView;
- (void)shutDownView;
- (void)userLogin;
- (void)uploadFailed;
- (void)refreshData;
- (NSArray *)purchaseRecords;

@end
