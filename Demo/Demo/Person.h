//
//  Person.h
//  Demo
//
//  Created by 谷胜亚 on 2018/7/17.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+SY_FMDBExtension.h"
#import <UIKit/UIKit.h>
@interface Third : NSObject

#pragma mark- <-----------  基础数据类型  ----------->
// int类型
@property (nonatomic, assign) int intValue;

// NSInteger类型
@property (nonatomic, assign) NSInteger integerValue;

// NSUInteger类型
@property (nonatomic, assign) NSUInteger uintegerValue;

// long long类型
@property (nonatomic, assign) long long longlongValue;

// int64_t类型
@property (nonatomic, assign) int64_t int64_tValue;

// CGFloat类型
@property (nonatomic, assign) CGFloat cgfloatValue;

// float类型
@property (nonatomic, assign) float floatValue;

// double类型
@property (nonatomic, assign) double doubleValue;

#pragma mark- <-----------  结构体  ----------->
// CGPoint类型
@property (nonatomic, assign) CGPoint cgpointValue;

// CGSize类型
@property (nonatomic, assign) CGSize cgsizeValue;

// CGRect类型
@property (nonatomic, assign) CGRect cgrectValue;

#pragma mark- <-----------  OC类型  ----------->
// NSString类型
@property (nonatomic, copy) NSString<SY_SAVE> *stringValue;

// NSArray类型
@property (nonatomic, copy) NSArray *arrayValue;

// NSMutableArray类型
@property (nonatomic, strong) NSMutableArray *mutablearrayValue;

// NSNumber类型
@property (nonatomic, copy) NSNumber *numberValue;

// NSDate类型
@property (nonatomic, copy) NSDate *dateValue;

// NSDate类型
@property (nonatomic, copy) NSData *dataValue;

#pragma mark- <-----------  嵌套  ----------->
// 直接嵌套
@property (nonatomic, strong) Third *thirdNest;

// 集合嵌套
@property (nonatomic, strong) NSMutableArray *thirdListNest;

@end

@interface Second : NSObject

#pragma mark- <-----------  基础数据类型  ----------->
// int类型
@property (nonatomic, assign) int intValue;

// NSInteger类型
@property (nonatomic, assign) NSInteger integerValue;

// NSUInteger类型
@property (nonatomic, assign) NSUInteger uintegerValue;

// long long类型
@property (nonatomic, assign) long long longlongValue;

// int64_t类型
@property (nonatomic, assign) int64_t int64_tValue;

// CGFloat类型
@property (nonatomic, assign) CGFloat cgfloatValue;

// float类型
@property (nonatomic, assign) float floatValue;

// double类型
@property (nonatomic, assign) double doubleValue;

#pragma mark- <-----------  结构体  ----------->
// CGPoint类型
@property (nonatomic, assign) CGPoint cgpointValue;

// CGSize类型
@property (nonatomic, assign) CGSize cgsizeValue;

// CGRect类型
@property (nonatomic, assign) CGRect cgrectValue;

#pragma mark- <-----------  OC类型  ----------->
// NSString类型
@property (nonatomic, copy) NSString *stringValue;

// NSArray类型
@property (nonatomic, copy) NSArray *arrayValue;

// NSMutableArray类型
@property (nonatomic, strong) NSMutableArray *mutablearrayValue;

// NSNumber类型
@property (nonatomic, copy) NSNumber *numberValue;

// NSDate类型
@property (nonatomic, copy) NSDate *dateValue;

// NSDate类型
@property (nonatomic, copy) NSData *dataValue;

#pragma mark- <-----------  嵌套  ----------->
// 直接嵌套
@property (nonatomic, strong) Third *thirdNest;

// 集合嵌套
@property (nonatomic, strong) NSMutableArray *thirdListNest;

@end

@interface First : NSObject

#pragma mark- <-----------  基础数据类型  ----------->
// int类型
@property (nonatomic, assign) int intValue;

// NSInteger类型
@property (nonatomic, assign) NSInteger integerValue;

// NSUInteger类型
@property (nonatomic, assign) NSUInteger uintegerValue;

// long long类型
@property (nonatomic, assign) long long longlongValue;

// int64_t类型
@property (nonatomic, assign) int64_t int64_tValue;

// CGFloat类型
@property (nonatomic, assign) CGFloat cgfloatValue;

// float类型
@property (nonatomic, assign) float floatValue;

// double类型
@property (nonatomic, assign) double doubleValue;

#pragma mark- <-----------  结构体  ----------->
// CGPoint类型
@property (nonatomic, assign) CGPoint cgpointValue; // 未保存,默认为zero

// CGSize类型
@property (nonatomic, assign) CGSize cgsizeValue; // 未保存,默认为zero

// CGRect类型
@property (nonatomic, assign) CGRect cgrectValue; // 未保存,默认为zero

#pragma mark- <-----------  OC类型  ----------->
// NSString类型
@property (nonatomic, copy) NSString *stringValue;

// NSArray类型
@property (nonatomic, copy) NSArray *arrayValue;

// NSMutableArray类型
@property (nonatomic, strong) NSMutableArray *mutablearrayValue;

// NSNumber类型
@property (nonatomic, copy) NSNumber *numberValue;

// NSDate类型
@property (nonatomic, copy) NSDate *dateValue; // 未保存

// NSDate类型
@property (nonatomic, copy) NSData *dataValue; // 未保存

#pragma mark- <-----------  嵌套  ----------->
// 直接嵌套
@property (nonatomic, strong) Second *secondNest;

// 集合嵌套
@property (nonatomic, strong) NSMutableArray *secondListNest;

@end

