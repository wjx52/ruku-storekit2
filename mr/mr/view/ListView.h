#import <UIKit/UIKit.h>

@interface ListView : UIView <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *receiptArr;
@property (nonatomic, copy) NSString *records;

- (instancetype)initWithFrame:(CGRect)frame withRecord:(NSString *)record;
- (void)setUpTableView;
- (void)setUpfunctionView;
- (void)deleteData;
- (NSString *)getCurrentTimes;
- (void)uploadDict:(NSDictionary *)dict;

@end
