//
//  NSObject+SY_FMDBExtension.h
//  
//
//  Created by 谷胜亚 on 2018/6/22.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SY_SAVE
@end

@interface NSObject (SY_FMDBExtension) <SY_SAVE>

#pragma mark- <-----------  数据库操作  ----------->
// FIXME: 新增
- (BOOL)sy_InsertWithError:(NSError *__autoreleasing*)error;

// FIXME: 更改
- (BOOL)sy_UpdateWithError:(NSError *__autoreleasing*)error;

// FIXME: 查询
+ (NSArray *)sy_FindAllWithError:(NSError **)error;
+ (NSArray *)sy_FindByCondition:(NSString *)condition error:(NSError * __autoreleasing *)error;

// FIXME: 删除
+ (BOOL)sy_RemoveByCondition:(NSString *)condition andError:(NSError *__autoreleasing*)error;
- (BOOL)sy_RemoveWithError:(NSError *__autoreleasing*)error;


#pragma mark- <-----------  可由类重写的方法  ----------->
/// 保存的属性名
+ (BOOL)sy_savedPropertyName:(NSString *)name;

/// 嵌套属性映射 -- key为属性名, value为嵌套的类名(NSString)
+ (NSDictionary<NSString*, NSString*> *)sy_nestPropertyMapList;

/// 类中属性名与表中字段名的映射
+ (NSDictionary<NSString*, NSString*> *)sy_propertyColumnMapList;

@end
