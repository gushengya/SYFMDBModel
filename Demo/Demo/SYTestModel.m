//
//  SYTestModel.m
//  Demo
//
//  Created by 谷胜亚 on 2021/2/1.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import "SYTestModel.h"
@implementation E
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    return YES;
}

//+ (NSDictionary *)__SY_NestClassMap
//{
//    return @{@"thirdNest":NSClassFromString(@"SYTestModelThird"), @"thirdListNest":NSClassFromString(@"SYTestModelThird"),};
//}
@end

@implementation D
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    return YES;
}

+ (NSDictionary *)__SY_NestClassMap
{
    Class class = NSClassFromString(@"E");
    return @{NSStringFromSelector(@selector(dArray)):class, NSStringFromSelector(@selector(dDictionary)):class, NSStringFromSelector(@selector(e)):class};
}
@end

@implementation C
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    return YES;
}

+ (NSDictionary *)__SY_NestClassMap
{
    Class class = NSClassFromString(@"D");
    return @{@"cArray":class, @"cDictionary":class, NSStringFromSelector(@selector(d)):class};
}
@end

@implementation B
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    if ([NSStringFromSelector(selector) isEqualToString:NSStringFromSelector(@selector(longlongValue))]) {
        return NO;
    }
    return YES;
}

+ (NSDictionary *)__SY_NestClassMap
{
    Class class = NSClassFromString(@"C");
    return @{@"bArray":class, @"bDictionary":class, NSStringFromSelector(@selector(c)):class};
}
@end

@implementation A
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector
{
    return YES;
}

+ (NSDictionary *)__SY_NestClassMap
{
    Class class = NSClassFromString(@"B");
    return @{@"aArray":class, @"aDictionary":class, NSStringFromSelector(@selector(b)):class};
}
@end

