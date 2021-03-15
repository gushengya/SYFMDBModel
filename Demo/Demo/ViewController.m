//
//  ViewController.m
//  Demo
//
//  Created by 谷胜亚 on 2018/7/12.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"
#import "SYTestModel.h"
@interface ViewController ()
@property (nonatomic, strong) UITextView *text;
@property (nonatomic, strong) UIImageView *imageView;

@end

static int count = 10;
@implementation ViewController

- (void)test
{
    [self insert];
    [self updateSelf];
    [self selectAll];
    [self delete];
}

- (void)insert
{
    E *e = [[E alloc] init];
    e.numberValue = @(1);
    e.dateValue = [NSDate date];
    e.dataValue = UIImagePNGRepresentation([UIImage imageNamed:@"8E7D412BF9A31BB59D6F6C7E92360220"]);
    
    D *d = [D new];
    d.e = e;
    d.dArray = @[e, e];
    d.dDictionary = @{@"key1":e, @"key2":e};
    d.cgrectValue = CGRectMake(1, 1, 1, 1);
    d.cgsizeValue = d.cgrectValue.size;
    d.cgpointValue = d.cgrectValue.origin;
    
    C *c = [C new];
    c.d = d;
    c.cArray = @[d, d];
    c.cDictionary = @{@"key1":d, @"key2":d};
    c.cgfloatValue = 1;
    c.floatValue = 1;
    c.doubleValue = 1;
    
    
    B *b = [B new];
    b.c = c;
    b.bArray = @[c, c];
    b.bDictionary = @{@"key1":c, @"key2":c};
    b.uintegerValue = 1;
    b.longlongValue = 1;
    b.int64_tValue = 1;
    
    A *a = [A new];
    a.b = b;
    a.aArray = @[b, b];
    a.aDictionary = @{@"key1":b, @"key2":b};
    a.intValue = 1;
    a.integerValue = 1;
    
    [a __SY_Insert];
}

- (void)delete
{
//    BOOL result = [A __SY_DeleteWithCondition:nil];
    NSArray *tmp = [A __SY_SelectAll];
    for (A *a in tmp) {
        [a __SY_Delete];
    }
//    NSLog(@"%d", result);
}

- (void)updateSelf
{
    int con = ++count;
    
    E *e = [[E alloc] init];
    e.numberValue = @(con);
    e.dateValue = [NSDate date];
    e.dataValue = UIImagePNGRepresentation([UIImage imageNamed:@"8E7D412BF9A31BB59D6F6C7E92360220"]);
    
    D *d = [D new];
    d.e = e;
    d.dArray = @[e, e];
    d.dDictionary = @{[NSString stringWithFormat:@"key%d", con]:e, [NSString stringWithFormat:@"KEY%d", con]:e};
    d.cgrectValue = CGRectMake(con, con, con, con);
    d.cgsizeValue = d.cgrectValue.size;
    d.cgpointValue = d.cgrectValue.origin;
    
    C *c = [C new];
    c.d = d;
    c.cArray = @[d, d];
    c.cDictionary = @{[NSString stringWithFormat:@"key%d", con]:d, [NSString stringWithFormat:@"KEY%d", con]:d};
    c.cgfloatValue = con;
    c.floatValue = con;
    c.doubleValue = con;
    
    
    B *b = [B new];
    b.c = c;
    b.bArray = @[c, c];
    b.bDictionary = @{[NSString stringWithFormat:@"key%d", con]:c, [NSString stringWithFormat:@"KEY%d", con]:c};
    b.uintegerValue = con;
    b.longlongValue = con;
    b.int64_tValue = con;
    
    A *a = [A new];
    a.b = b;
    a.aArray = @[b, b];
    a.aDictionary = @{[NSString stringWithFormat:@"key%d", con]:b, [NSString stringWithFormat:@"KEY%d", con]:b};
    a.intValue = con;
    a.integerValue = con;
    
    NSArray *tmp = [A __SY_SelectAll];
    for (A *model in tmp) {
        model.b = a.b;
        model.aArray = a.aArray;
        model.aDictionary = a.aDictionary;
        model.intValue = a.intValue;
        model.integerValue = a.integerValue;
        [model __SY_Update];
    }
}

- (void)selectAll
{
    NSArray *tmp = [A __SY_SelectAll];
    for (A *a in tmp)
    {
        NSDictionary *dic = a.aDictionary;
        for (B *b in dic.allValues) {
            NSDictionary *dic1 = b.bDictionary;
            for (C *c in dic1.allValues) {
                NSDictionary *dic2 = c.cDictionary;
                for (D *d in dic2.allValues) {
                    NSDictionary *dic3 = d.dDictionary;
                    for (E *e in dic3.allValues) {
                        self.imageView.image = [UIImage imageWithData:e.dataValue];
                    }
                }
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self test];
    
    UIButton *insert = [[UIButton alloc] initWithFrame:CGRectMake(30, 100, 50, 50)];
    [insert setBackgroundColor:[UIColor redColor]];
    [insert addTarget:self action:@selector(insertbtnClick) forControlEvents:UIControlEventTouchUpInside];
    [insert setTitle:@"插入" forState:UIControlStateNormal];
    [insert setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [insert setBackgroundColor:[UIColor grayColor]];
    [self.view addSubview:insert];
    
    UIButton *delete = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(insert.frame) + 30, 100, 50, 50)];
    [delete setBackgroundColor:[UIColor redColor]];
    [delete addTarget:self action:@selector(deletebtnClick) forControlEvents:UIControlEventTouchUpInside];
    [delete setTitle:@"删除" forState:UIControlStateNormal];
    [delete setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [delete setBackgroundColor:[UIColor grayColor]];
    [self.view addSubview:delete];
    
    UIButton *update = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(delete.frame) + 30, 100, 50, 50)];
    [update setBackgroundColor:[UIColor redColor]];
    [update addTarget:self action:@selector(updatebtnClick) forControlEvents:UIControlEventTouchUpInside];
    [update setTitle:@"更新" forState:UIControlStateNormal];
    [update setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [update setBackgroundColor:[UIColor grayColor]];
    [self.view addSubview:update];
    
    UIButton *select = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(update.frame) + 30, 100, 50, 50)];
    [select setBackgroundColor:[UIColor redColor]];
    [select addTarget:self action:@selector(selectbtnClick) forControlEvents:UIControlEventTouchUpInside];
    [select setTitle:@"查询" forState:UIControlStateNormal];
    [select setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [select setBackgroundColor:[UIColor grayColor]];
    [self.view addSubview:select];
    
    UITextView *text = [[UITextView alloc] init];
    text.frame = CGRectMake(insert.frame.origin.x, CGRectGetMaxY(update.frame) + 50, CGRectGetMaxX(select.frame) - insert.frame.origin.x, 400);
    text.backgroundColor = [UIColor colorWithRed:244.0/255 green:244.0/255 blue:244.0/255 alpha:1.0];
    [self.view addSubview:text];
    self.text = text;
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.frame = CGRectMake(insert.frame.origin.x, CGRectGetMaxY(text.frame) + 50, text.frame.size.width, 300);
    [self.view addSubview:imageView];
    imageView.backgroundColor = [UIColor colorWithRed:244.0/255 green:244.0/255 blue:244.0/255 alpha:1.0];
    self.imageView = imageView;
}

- (void)insertbtnClick
{
    [self insert];
}

- (void)deletebtnClick
{
    [self delete];
}

- (void)updatebtnClick
{
    [self updateSelf];
}

- (void)selectbtnClick
{
    [self selectAll];
}

@end
