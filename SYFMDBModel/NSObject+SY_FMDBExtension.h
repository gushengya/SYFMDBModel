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
/**
 *  实例对象调用新增
 *
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 插入的结果
 */
- (BOOL)sy_InsertWithError:(NSError *__autoreleasing*)error;

// FIXME: 更改
/**
 *  更新数据
 *
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 更新是否成功
 */
- (BOOL)sy_UpdateWithError:(NSError *__autoreleasing*)error;

/**
 *  更新单列字段的值
 *
 *  @param name 即将被更改值的字段名
 *  @param value 更改后的值
 *  @param condition 以@"where key = 'value'"格式作为条件语句
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 更新结果
 */
+ (BOOL)sy_UpdateName:(NSString *)name newValue:(id)value condition:(NSString *)condition error:(NSError *__autoreleasing*)error;

// FIXME: 查询
/**
 *  查询某表所有数据
 *
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 调用类的对象list, 语句错误时为nil, 其他时候为NSArray对象可能为空对象
 */
+ (NSArray *)sy_FindAllWithError:(NSError **)error;

/**
 *  按条件查询表中数据
 *
 *  @param condition 以@"where key = 'value'"格式作为条件查询语句
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 调用类的对象list, 语句错误时为nil, 其他时候为NSArray对象可能为空对象
 */
+ (NSArray *)sy_FindByCondition:(NSString *)condition error:(NSError * __autoreleasing *)error;

/**
 *  完整查询语句进行查询, 需要自己拼接所需的查询语句(包括被查询的表名)
 *
 *  @param name 被查询的字段名(不可为嵌套属性名)
 *  @param condition 以@"where key = 'value'"格式作为条件查询语句
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 所要查询的结果集, 语句错误时为nil, 其他时候为NSArray对象可能为空对象
 */
+ (NSArray *)sy_FindName:(NSString *)name condition:(NSString *)condition error:(NSError * __autoreleasing *)error;

// FIXME: 删除
/**
 *  通过条件删除数据库中数据
 *
 *  @param condition 以@"where key = 'value'"格式作为条件查询语句
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 删除的结果
 */
+ (BOOL)sy_RemoveByCondition:(NSString *)condition andError:(NSError *__autoreleasing*)error;

/**
 *  实例对象调用删除
 *
 *  @param error 传入NSError的地址, 如有错误会赋值一个NSError对象
 *
 *  @return 删除的结果
 */
- (BOOL)sy_RemoveWithError:(NSError *__autoreleasing*)error;


#pragma mark- <-----------  可由类重写的方法  ----------->
/// 保存的属性名
+ (BOOL)sy_savedPropertyName:(NSString *)name;

/// 嵌套属性映射 -- key为属性名, value为嵌套的类名(NSString)
+ (NSDictionary<NSString*, NSString*> *)sy_nestPropertyMapList;

/// 类中属性名与表中字段名的映射
+ (NSDictionary<NSString*, NSString*> *)sy_propertyColumnMapList;

@end
