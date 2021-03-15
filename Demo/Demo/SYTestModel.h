//
//  SYTestModel.h
//  Demo
//
//  Created by 谷胜亚 on 2021/2/1.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import "SYBaseModel.h"
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface E : SYBaseModel
// NSNumber类型
@property (nonatomic, copy) NSNumber *numberValue;

// NSDate类型
@property (nonatomic, copy) NSDate *dateValue;

// NSDate类型
@property (nonatomic, copy) NSData *dataValue;
@end

@interface D : E
// CGPoint类型
@property (nonatomic, assign) CGPoint cgpointValue;

// CGSize类型
@property (nonatomic, assign) CGSize cgsizeValue;

// CGRect类型
@property (nonatomic, assign) CGRect cgrectValue;

@property (nonatomic, copy) NSArray *dArray;
@property (nonatomic, copy) NSDictionary *dDictionary;
@property (nonatomic, strong) E *e;
@end

@interface C : D
// CGFloat类型
@property (nonatomic, assign) CGFloat cgfloatValue;

// float类型
@property (nonatomic, assign) float floatValue;

// double类型
@property (nonatomic, assign) double doubleValue;

@property (nonatomic, copy) NSArray *cArray;
@property (nonatomic, copy) NSDictionary *cDictionary;
@property (nonatomic, strong) D *d;
@end

@interface B : C
// NSUInteger类型
@property (nonatomic, assign) NSUInteger uintegerValue;

// long long类型
@property (nonatomic, assign) long long longlongValue;

// int64_t类型
@property (nonatomic, assign) int64_t int64_tValue;

@property (nonatomic, copy) NSArray *bArray;
@property (nonatomic, copy) NSDictionary *bDictionary;
@property (nonatomic, strong) C *c;
@end

@interface A : B
// int类型
@property (nonatomic, assign) int intValue;

// NSInteger类型
@property (nonatomic, assign) NSInteger integerValue;
@property (nonatomic, copy) NSArray *aArray;
@property (nonatomic, copy) NSDictionary *aDictionary;
@property (nonatomic, strong) B *b;
@end


NS_ASSUME_NONNULL_END
