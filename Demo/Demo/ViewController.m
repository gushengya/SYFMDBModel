//
//  ViewController.m
//  Demo
//
//  Created by 谷胜亚 on 2018/7/12.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//        [self add];
//    [self remove];
//        [self update];
//        [self select];
    
    BOOL result = [Third sy_UpdateName:@"dateValue" newValue:nil condition:@"" error:nil];
    
    NSArray *array = [Third sy_FindName:@"dateValue" condition:@"" error:nil];
    for (NSValue *value in array) {
        NSLog(@"(1)%@", value);
    }
}


// 增
- (void)add
{
    Third *third = [[Third alloc] init];
    third.intValue = 1;
    third.integerValue = 1;
    third.uintegerValue = 1;
    third.longlongValue = 1;
    third.int64_tValue = 1;
    third.cgfloatValue = 1.1;
    third.floatValue = 1.1;
    third.doubleValue = 1.1;
    
    third.cgpointValue = CGPointMake(10, 10);
    third.cgsizeValue = CGSizeMake(10, 10);
    third.cgrectValue = CGRectMake(10, 10, 10, 10);
    
    third.stringValue = @"第三个字符串";
    third.arrayValue = @[@"1", @"2", @"3"];
    third.mutablearrayValue = @[@"11", @"22", @"33"].mutableCopy;
    third.numberValue = @(1);
    third.dateValue = [NSDate date];
    third.dataValue = UIImagePNGRepresentation([UIImage imageNamed:@"8E7D412BF9A31BB59D6F6C7E92360220"]);
    
    third.thirdNest = nil;
    third.thirdListNest = nil;
    
    
    
    Third *third1 = [[Third alloc] init];
    third1.intValue = 2;
    third1.integerValue = 2;
    third1.uintegerValue = 2;
    third1.longlongValue = 2;
    third1.int64_tValue = 2;
    third1.cgfloatValue = 2;
    third1.floatValue = 2;
    third1.doubleValue = 2;
    
    third1.cgpointValue = CGPointMake(102, 102);
    third1.cgsizeValue = CGSizeMake(102, 102);
    third1.cgrectValue = CGRectMake(102, 102, 102, 102);
    
    third1.stringValue = @"第三个字符串";
    third1.arrayValue = @[@"1", @"2", @"3"];
    third1.mutablearrayValue = @[@"11", @"22", @"33"].mutableCopy;
    third1.numberValue = @(1 + 2);
    third1.dateValue = [NSDate date];
    third1.dataValue = [NSData data];
    
    third1.thirdNest = third;
    third1.thirdListNest = @[third, third].mutableCopy;
    
    
    Second *second = [[Second alloc] init];
    second.intValue = 3;
    second.integerValue = 3;
    second.uintegerValue = 3;
    second.longlongValue = 3;
    second.int64_tValue = 3;
    second.cgfloatValue = 3;
    second.floatValue = 3;
    second.doubleValue = 3;
    
    second.cgpointValue = CGPointMake(3, 3);
    second.cgsizeValue = CGSizeMake(3, 3);
    second.cgrectValue = CGRectMake(3, 3, 3, 3);
    
    second.stringValue = @"第二个字符串";
    second.arrayValue = @[@"1", @"2", @"3"];
    second.mutablearrayValue = @[@"11", @"22", @"33"].mutableCopy;
    second.numberValue = @(3);
    second.dateValue = [NSDate date];
    second.dataValue = [NSData data];
    
    second.thirdNest = third1;
    second.thirdListNest = @[third1, third, third1].mutableCopy;
    
    
    First *first = [[First alloc] init];
    first.intValue = 4;
    first.integerValue = 4;
    first.uintegerValue = 4;
    first.longlongValue = 4;
    first.int64_tValue = 4;
    first.cgfloatValue = 4;
    first.floatValue = 4;
    first.doubleValue = 4;
    
    first.cgpointValue = CGPointMake(4, 4);
    first.cgsizeValue = CGSizeMake(4, 4);
    first.cgrectValue = CGRectMake(4, 4, 4, 4);
    
    first.stringValue = @"第一个字符串";
    first.arrayValue = @[@"1", @"2", @"3"];
    first.mutablearrayValue = @[@"11", @"22", @"33"].mutableCopy;
    first.numberValue = @(4);
    first.dateValue = [NSDate date];
    first.dataValue = UIImagePNGRepresentation([UIImage imageNamed:@"myIcon"]);
    
    first.secondNest = second;
    first.secondListNest = @[second, second].mutableCopy;
    
    NSError *error = nil;
    BOOL result = [first sy_InsertWithError:&error];
    
    NSArray *arr = [First sy_FindAllWithError:&error];
    NSLog(@"%@ -- %d", arr, result);
}

// 删
- (void)remove
{
    NSError *error = nil;
    BOOL result = [First sy_RemoveByCondition:@"" andError:&error];
    NSLog(@"%d", result);
}

// 改
- (void)update
{
    Second *second = [[Second alloc] init];
    second.intValue = 3;
    second.integerValue = 3;
    second.uintegerValue = 3;
    second.longlongValue = 3;
    second.int64_tValue = 3;
    second.cgfloatValue = 3;
    second.floatValue = 3;
    second.doubleValue = 3;
    
    second.cgpointValue = CGPointMake(11.33, 333.223);
    second.cgsizeValue = CGSizeMake(333.13, 33.134);
    second.cgrectValue = CGRectMake(3.78, 3.53, 3.23, 3.44);
    
    second.stringValue = @"第二个字符串";
    second.arrayValue = @[@"1", @"2", @"3"];
    second.mutablearrayValue = @[@"11", @"22", @"33"].mutableCopy;
    second.numberValue = @(3);
    second.dateValue = [NSDate date];
    second.dataValue = UIImagePNGRepresentation([UIImage imageNamed:@"myIcon"]);
    
    second.thirdNest = nil;
    second.thirdListNest = nil;
    
    
    
    NSError *error = nil;
    NSArray *arr = [First sy_FindAllWithError:&error];
    for (First *first in arr) {
        first.stringValue = @"谷胜亚";
        first.secondNest = second;
        first.secondListNest = nil;
        BOOL result = [first sy_UpdateWithError:&error];
        NSLog(@"%d", result);
    }
    NSLog(@"%@", arr);
}

// 查
- (void)select
{
    NSError *error = nil;
    
    
    NSArray *arr = [First sy_FindAllWithError:&error];
    for (First *first in arr) {
        NSData *data = first.dataValue;
        UIImageView *img = [[UIImageView alloc] init];
        UIImage *image = [UIImage imageWithData:data];
        img.image = image;
        img.frame = CGRectMake(50, 50, image.size.width, image.size.height);
        [self.view addSubview:img];
    }
    NSLog(@"%@", arr);
}


@end
