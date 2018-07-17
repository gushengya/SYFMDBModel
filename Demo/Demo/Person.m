//
//  Person.m
//  Demo
//
//  Created by 谷胜亚 on 2018/7/17.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "Person.h"


@implementation First

+ (NSDictionary<NSString *,NSString *> *)sy_nestPropertyMapList
{
    return @{@"secondNest": @"Second", @"secondListNest": @"Second"};
}

+ (BOOL)sy_savedPropertyName:(NSString *)name
{
    return YES;
}

@end


@implementation Second

+ (NSDictionary<NSString *,NSString *> *)sy_nestPropertyMapList
{
    return @{@"thirdNest": @"Third", @"thirdListNest": @"Third"};
}

+ (BOOL)sy_savedPropertyName:(NSString *)name
{
    return YES;
}

@end

@implementation Third

+ (NSDictionary<NSString *,NSString *> *)sy_nestPropertyMapList
{
    return @{@"thirdNest": @"Third", @"thirdListNest": @"Third"};
}

+ (BOOL)sy_savedPropertyName:(NSString *)name
{
    return YES;
}

@end


