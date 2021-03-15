//
//  SYBaseModel.m
//  Demo
//
//  Created by 谷胜亚 on 2021/1/27.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import "SYBaseModel.h"
#import "NSObject+SY_FMDBExtension.h"
#import "SY_FMDBManager.h"
#import "SYPropertyInfo.h"
#import <UIKit/UIKit.h>
/// 主键定死的列名(自增从1开始)
static NSString *const SY_SQLITE_PRIMARY_KEY = @"SY_SQLITE_PRIMARY_KEY";
/// SQLite数据库中表与上一级表进行关联的头结点名称(表的列名)(头结点格式:上级表名+分割字+属性名+分割字+上级表该条数据主键值)
static NSString *const SY_SQLITE_SUPERIOR_TABLE_HEADNODE = @"SY_SQLITE_SUPERIOR_TABLE_HEADNODE";
/// SQLite数据库中的分割关键字
static NSString *const SY_SQLITE_SPLIT_KEY = @"SY_SQLITE_SPLIT_KEY";
static NSMutableArray *instanceClasses;

@interface SYBaseModel ()

/// 主键(只读属性不存储)
@property (nonatomic, assign, readonly) long long primaryKey;

/// 嵌套时关联上级属性信息的头结点字段
@property (nonatomic, copy, readonly) NSString *superiorHeadNode;

@end

@implementation SYBaseModel

#pragma mark- 数据库操作

/// !!!:插入数据
- (BOOL)__SY_Insert
{
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self __SY_InsertWithSuperiorHeadNode:nil database:db rollback:rollback];
    }];
    
    return result;
}

/// 插入调用者对象到调用者类所表示的表中(支持递归嵌套)
/// @param superiorHeadNode 该嵌套对象是否存在于上一级嵌套数据的属性中
/// @param db 数据库操作对象
/// @param rollback 是否回滚
/// @return 该插入操作是否成功, 如果不成功则回滚
- (BOOL)__SY_InsertWithSuperiorHeadNode:(NSString *)superiorHeadNode database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    // 谁调起配置谁的表
    if (![self.class __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return NO;
    
    __block BOOL result = YES;
    
    [self __SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:superiorHeadNode completionHandler:^(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues) {
        // 拼接sql语句
        NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", NSStringFromClass([self class]), cacheEnablePropertyNameSQLiteString, cacheEnablePropertySignSQLiteString];
        
        // 执行语句使数据存储
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:cacheEnablePropertyValues];
        if (isSuccess)
        {
            // 获取该条数据存储到数据库中的主键值(该值唯一且递增)
            int64_t pkID = db.lastInsertRowId;
            self->_primaryKey = pkID;
            self->_superiorHeadNode = superiorHeadNode;
            [self __SY_HandleNestDataWithRecursionOperation:^(SYPropertyInfo *info, id recursionValue) {
                if ([recursionValue isKindOfClass:[NSDictionary class]])
                {
                    // 遍历字典
                    for (id keyOfDic in [recursionValue allKeys])
                    {
                        id valueOfDic = [recursionValue objectForKey:keyOfDic];
                        // 拼接头结点语句
                        NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:keyOfDic];
                        [valueOfDic __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                    }
                }
                else if ([recursionValue isKindOfClass:[NSArray class]] || [recursionValue isKindOfClass:[NSSet class]])
                {
                    // 遍历数组或集合
                    for (id valueOfArr in recursionValue)
                    {
                        // 拼接头结点语句
                        NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:nil];
                        [valueOfArr __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                    }
                }
                else if (recursionValue)
                {
                    // 拼接头结点语句
                    NSString *headnode = [self.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:pkID keyOfDict:nil];
                    [recursionValue __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback];
                }
                else // 空值
                {
                    // 空值不走嵌套递归流程
                }
            }];
        }
        else // 插入失败
        {
            NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的非嵌套部分插入数据失败:(%@)", NSStringFromClass([self class]), sqlString];
            NSLog(@"[SY_Error]%@", logKey);
            *rollback = YES;
            result = NO;
        }
        
        // 如最后插入失败, 则将主键值归零(有漏洞, 嵌套树中可能存在未归零的)
        if (!result)
        {
            self->_primaryKey = 0;
        }
    }];
    
    return result;
}

/// !!!:删除数据
/// 删除当前对象主键对应的数据
- (BOOL)__SY_Delete
{
    if (self.primaryKey <= 0) return NO;
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 获取where及之后的字段
        NSString *str = [self.class __SY_GetTheStringAfterTheTableNameWithCondition:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %lld;", NSStringFromClass(self.class), SY_SQLITE_PRIMARY_KEY, self.primaryKey]];
        result = [self.class __SY_DeleteWithCondition:str fromTableClass:self.class database:db rollback:rollback];
    }];
    return result;
}

/// 根据条件删除数据
/// 调用者类为想要删除的数据所在表名
/// 例子: DELETE FROM STUDENT WHERE age < 25;
/// @param condition 删除的条件
+ (BOOL)__SY_DeleteWithCondition:(NSString * __nullable)condition
{
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        // 获取where及之后的字段
        NSString *str = [self __SY_GetTheStringAfterTheTableNameWithCondition:condition];
        result = [self __SY_DeleteWithCondition:str fromTableClass:self database:db rollback:rollback];
    }];
    
    return result;
}

/// 根据指定的即将删除的模型执行删除语句
/// @param willDeletedModel 即将被删除的模型
/// @param db 数据库对象
/// @param rollback 是否回滚
+ (BOOL)__SY_DeleteWithWillDeletedModel:(SYBaseModel *)willDeletedModel database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    // 1.判断主键是否存在
    if (willDeletedModel.primaryKey <= 0) return NO;
    
    // 2.遍历该对象的嵌套属性列表
    BOOL result = YES;
    NSDictionary *nestPropertyList = [willDeletedModel.class __SY_NestPropertyInfo];
    for (NSString *propertyName in nestPropertyList.allKeys)
    {
        // 3.取得对应的嵌套属性信息对象
        SYPropertyInfo *info = [nestPropertyList objectForKey:propertyName];
        
        // 4.判断该属性的类型
        id value = [willDeletedModel valueForKey:propertyName];
        
        // 属性值为空的情况下不走嵌套逻辑
        if (!value || [value isKindOfClass:[NSNull class]]) continue;
        if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSSet class]])
        {
            // 5.遍历数组型集合得到对应嵌套的对象
            for (SYBaseModel *modelOfArr in value)
            {
                if (![self __SY_DeleteWithWillDeletedModel:modelOfArr database:db rollback:rollback]) result = NO;
            }
        }
        else if ([info.ocType isSubclassOfClass:[NSDictionary class]])
        {
            // 6.遍历字典得到对应嵌套的对象
            for (SYBaseModel *modelOfDic in [value allValues])
            {
                if (![self __SY_DeleteWithWillDeletedModel:modelOfDic database:db rollback:rollback]) result = NO;
            }
        }
        else
        {
            // 7.直接嵌套的对象调起查找嵌套方法
            if (![self __SY_DeleteWithWillDeletedModel:value database:db rollback:rollback]) result = NO;
        }
    }
    
    if (!result)
    {
        *rollback = YES;
        return NO;
    }
    
    // 8.拼接删除数据的语句
    NSString *deleteString = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %lld;", NSStringFromClass(willDeletedModel.class), SY_SQLITE_PRIMARY_KEY, willDeletedModel.primaryKey];
    
    // 9.执行SQLite语句
    BOOL isSuccess = [db executeUpdate:deleteString];
    if (!isSuccess)
    {
        NSAssert(NO, @"执行该删除语句出现错误:%@", deleteString);
        result = NO;
        *rollback = YES;
    }
    
    return result;
}

/// 根据指定的删除语句执行删除语句
/// 调用者类为想要删除的数据所在的数据库表名
/// @param condition 删除语句(类似WHERE age < 25;)
/// @param db 数据库对象
/// @param rollback 是否回滚
/// @param tableClass 想要删除的数据所在的数据库表名
+ (BOOL)__SY_DeleteWithCondition:(NSString *)condition fromTableClass:(Class)tableClass database:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    // 谁调起配置谁的表
    if (![tableClass __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return NO;
    
    BOOL result = YES;
    
    // 1.拼接查询语句
    NSString *selectString = [NSString stringWithFormat:@"SELECT * FROM %@ %@", NSStringFromClass(tableClass), condition];
    
    // 2.查询出对应的数据
    NSArray *resultArray = [tableClass __SY_SelectWithCondition:selectString database:db rollback:rollback];
    
    // 3.遍历
    for (SYBaseModel *model in resultArray)
    {
        // 指定项递归删除
        result = [self __SY_DeleteWithWillDeletedModel:model database:db rollback:rollback];
    }
    
    return result;
}

/// !!!:更改
- (BOOL)__SY_Update
{
    if (self.primaryKey <= 0) return NO;
    __block BOOL result = YES;
    __weak typeof(self) weakSelf = self;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        NSArray *data = [weakSelf.class __SY_SelectWithCondition:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = %lld;", NSStringFromClass([weakSelf class]), SY_SQLITE_PRIMARY_KEY, weakSelf.primaryKey] database:db rollback:rollback];
        
        if (data.count > 0)
        {
            if (![self.class __SY_UpdateModel:data.firstObject toModel:weakSelf WithDatabase:db rollback:rollback]) result = NO;
        }
        else result = NO;
    }];
    
    return result;
}

/// 将模型A在数据库中的值更新为模型B的值
/// @param model 模型A, 数据库中查找出来的值, 必须有主键, 才支持更新操作
/// @param toModel 模型B, 想要更新成的值, 不要求主键
/// @param db 数据库操作对象
/// @param rollback 是否回滚
+ (BOOL)__SY_UpdateModel:(SYBaseModel *)model toModel:(SYBaseModel *)toModel WithDatabase:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    __block BOOL result = YES;
    if (model.primaryKey <= 0) return NO;
    
    // 如果存在嵌套属性, 则先遍历嵌套属性, 判定模型A与模型B产生交集的部分将其更新
    [toModel __SY_HandleNestDataWithRecursionOperation:^(SYPropertyInfo *info, id recursionValue) {
        
        // 取出数据库中该数据所对应的模型中该属性的值
        id valueOfModel = [model valueForKey:info.name];
        
        // 1.属性为字典
        if ([info.ocType isSubclassOfClass:[NSDictionary class]])
        {
            // 1.1即将替换的属性的值不存在, 则移除数据库中原本就有的, 同时将数据库查询出来的model对应的属性值置为nil
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                NSDictionary *dicOfNest = valueOfModel;
                for (SYBaseModel *valueOfDic in dicOfNest.allValues)
                {
                    if (![valueOfDic isKindOfClass:info.associateClass]) continue;
                    
                    // 1.2移除数据库中指定的数据
                    if (![self __SY_DeleteWithWillDeletedModel:valueOfDic database:db rollback:rollback]) result = NO;
                }
                
                // 1.3将数据库模型中的该嵌套属性置为nil
                [model setValue:nil forKey:info.name];
            }
            else
            {
                // 1.4遍历该属性对应的字典值
                for (id keyOfDic in recursionValue)
                {
                    id valueOfDic = [recursionValue objectForKey:keyOfDic];
                    
                    // 1.5如果数据库中查找出来的数据对应属性值表示的字典中存在该key, 则更新该值到数据库中
                    if ([[valueOfModel allKeys] containsObject:keyOfDic])
                    {
                        id valueOfDicInModel = [valueOfModel objectForKey:keyOfDic];
                        if (![self __SY_UpdateModel:valueOfDicInModel toModel:valueOfDic WithDatabase:db rollback:rollback]) result = NO;
                    }
                    // 1.6表示数据库中没有该字典中对应的嵌套对象, 需要新增到数据库中
                    else
                    {
                        NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:keyOfDic];
                        if (![valueOfDic __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
                    }
                }
                
                // 1.7筛选出在数据库表中, 但不在当前模型属性值中的key数组
                // 数据库中取出的列名数组集合范围小, 而属性名数组集合范围大, 所以需要求得在大集合但没有在小集合中的部分
                NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", [recursionValue allKeys]];
                NSArray *needDeleteKeys = [[valueOfModel allKeys] filteredArrayUsingPredicate:filterPredicate];
                
                // 1.8遍历筛选出来的keys, 然后移除
                for (id keyOfNeedDeleteKeys in needDeleteKeys)
                {
                    id tmpValue = [valueOfModel objectForKey:keyOfNeedDeleteKeys];
                    if (![self __SY_DeleteWithWillDeletedModel:tmpValue database:db rollback:rollback]) result = NO;
                }
                
                // 1.9本来应该讲更新后的字典重新赋值给数据库查询出来的模型的指定属性的, 后续再思考
            }
        }
        // 2.属性为数组或集合
        else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSSet class]])
        {
            // 2.1即将替换的属性的值不存在, 则移除数据库中原本就有的, 同时将数据库查询出来的model对应的属性值置为nil
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                NSArray *arrOfNest = valueOfModel;
                for (SYBaseModel *valueOfDic in arrOfNest)
                {
                    if (![valueOfDic isKindOfClass:info.associateClass]) continue;
                    
                    // 2.2移除数据库中指定的数据
                    if (![self __SY_DeleteWithWillDeletedModel:valueOfDic database:db rollback:rollback]) result = NO;
                }
                
                // 2.3将数据库模型中的该嵌套属性置为nil
                [model setValue:nil forKey:info.name];
            }
            else
            {
                // 2.4遍历该属性对应的数组值
                for (int i = 0; i < [recursionValue count]; i++)
                {
                    SYBaseModel *itemOfNewArr = [recursionValue objectAtIndex:i];
                    
                    // 2.5如果未越界, 则更新数据库中的值
                    if (i < [valueOfModel count])
                    {
                        SYBaseModel *itemOfOldArr = [valueOfModel objectAtIndex:i];
                        if (![self __SY_UpdateModel:itemOfOldArr toModel:itemOfNewArr WithDatabase:db rollback:rollback]) result = NO;
                    }
                    // 2.6如果越界了, 表示新数据比老数据多, 需要新增
                    else
                    {
                        NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:nil];
                        if (![itemOfNewArr __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
                    }
                }
                
                // 2.7判定是否老数据比新数据多, 如果多, 则删除多余的部分
                if ([valueOfModel count] > [recursionValue count])
                {
                    for (NSUInteger i = [valueOfModel count] - 1; i >= [recursionValue count]; i--)
                    {
                        SYBaseModel *itemOfNewArr = [valueOfModel objectAtIndex:i];
                        if (![self __SY_DeleteWithWillDeletedModel:itemOfNewArr database:db rollback:rollback]) result = NO;
                    }
                }
                
                // 2.8本来应该讲更新后的字典重新赋值给数据库查询出来的模型的指定属性的, 后续再思考
                
            }
        }
        // 3.属性为直接嵌套
        else
        {
            // 3.1即将替换的属性的值不存在, 则移除数据库中原本就有的, 同时将数据库查询出来的model对应的属性值置为nil
            if (!recursionValue || [recursionValue isKindOfClass:[NSNull class]])
            {
                SYBaseModel *modelOfNest = valueOfModel;
                
                // 3.2移除数据库中指定的数据
                if (modelOfNest)
                {
                    if (![self __SY_DeleteWithWillDeletedModel:modelOfNest database:db rollback:rollback]) result = NO;
                }
                
                // 3.3将数据库模型中的该嵌套属性置为nil
                [model setValue:nil forKey:info.name];
            }
            // 3.4存在新值, 且老值不存在, 则新增
            else if (!valueOfModel || [valueOfModel isKindOfClass:[NSNull class]])
            {
                NSString *headnode = [model.class __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:model.primaryKey keyOfDict:nil];
                if (![recursionValue __SY_InsertWithSuperiorHeadNode:headnode database:db rollback:rollback]) result = NO;
            }
            // 3.4存在新值, 且老值存在, 则更新
            else
            {
                if (![self __SY_UpdateModel:valueOfModel toModel:recursionValue WithDatabase:db rollback:rollback]) result = NO;
            }
        }
    }];
    
    if (!result) return NO;
    
    // 4.更新非嵌套部分
    [toModel __SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:model.superiorHeadNode completionHandler:^(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues) {
        
        // 4.1生成更新语句
        NSString *sqlString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = %lld;", NSStringFromClass([model class]), cacheEnablePropertyNameAndSign, SY_SQLITE_PRIMARY_KEY, model.primaryKey];
        
        // 4.2执行语句使数据存储
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:cacheEnablePropertyValues];
        if (!isSuccess)
        {
            NSLog(@"更新语句发生错误:%@", sqlString);
            *rollback = YES;
            result = NO;
        }
    }];
    
    return result;
}

/// !!!:查询
/// 查找调用者类名所对应数据库表的所有数据(如果属性中存在嵌套, 则也会将嵌套表中的数据查询出来并赋值给对应属性)
/// 例子: SELECT * FROM table_name;
/// @return 返回查询结果, 未找到结果是@[], 而不是nil
+ (NSArray *)__SY_SelectAll
{
    // 拼接删除语句
    NSString *selectStr = [NSString stringWithFormat:@"SELECT * FROM %@;", NSStringFromClass(self)];
    return [self __SY_SelectWithCondition:selectStr];
}

/// 查找调用者类名所对应数据库表中指定查询条件的数据
/// 例子: SELECT * FROM table_name where name = '小明';
/// @param condition 指定的查询条件
/// @return 返回查询结果, 未找到结果是@[], 而不是nil
+ (NSArray *)__SY_SelectWithCondition:(NSString * __nullable)condition
{
    __block NSArray *result = nil;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *str = condition;
        
        // 检索查询条件, 得到where后的内容
        str = [self __SY_GetTheStringAfterTheTableNameWithCondition:str];
        
        // 拼接上where前的内容
        str = [NSString stringWithFormat:@"SELECT * FROM %@ %@", NSStringFromClass(self), str];
        
        // 开始查询
        result = [self __SY_SelectWithCondition:str database:db rollback:rollback];
    }];
    
    return result;
}

/// 谁调起就查询谁, 返回谁的对象数组
/// @param condition 查询的条件
/// @param db 数据库操作对象
/// @param rollback 是否回滚
/// @return 返回发起调用的类的实例对象数组, 表中不存在数据则返回@[]
+ (NSArray *)__SY_SelectWithCondition:(NSString *)condition database:(FMDatabase *_Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    // 2 初始化一个可变数组保存转变完的模型
    NSMutableArray *resultList = [NSMutableArray array];
    // 谁调起配置谁的表
    if (![self __SY_ConfigSQLiteTableWithDB:db rollback:rollback]) return resultList;
    // 执行sql语句
    FMResultSet *resultSet = [db executeQuery:condition];
    
    // 1. 表示查询出错
    if (resultSet == nil) return resultList;
    
    // 获取存储变量信息对象列表
    NSDictionary *cacheDic = [self __SY_CacheEnablePropertyInfo];
    
    // 3. 遍历结果集(结果集中是一条条数据[数据中不包含嵌套的属性])
    while ([resultSet next]) // 当结果集中仍然有下一条数据时进入循环
    {
        // 取该条数据字典
        NSDictionary *dic = [resultSet resultDictionary];
        
        // !!!:别忘了工厂模式需要以子类初始化, 父类接收
        SYBaseModel *model = [[self alloc] init];
        
        // 获取数据库表中该条数据的主键值
        long long primaryKey = [[dic valueForKey:SY_SQLITE_PRIMARY_KEY] longLongValue];
        
        // 获取上级头结点
        NSString *superiorHeadNode = [dic valueForKey:SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
        if ([superiorHeadNode isKindOfClass:[NSNull class]]) superiorHeadNode = nil;
        
        // 取该条数据对应字段的值
        for (id key in dic.allKeys)
        {
            id value = dic[key];
            // 根据字段名获取对应的属性信息对象
            SYPropertyInfo *info = cacheDic[key];
            
            // 判断属性的类型
            if (info.variableType == SY_Variable_TYPE_UNKNOW)
            {
                // 未知类型不赋值
            }
            else if (info.variableType == SY_Variable_TYPE_OBJECTC)
            {
                if (info.associateClass) // 为嵌套属性
                {
                    if ([info.ocType isSubclassOfClass:[NSDictionary class]]) // 嵌套类型为字典
                    {
                        if (!value || [value isKindOfClass:[NSNull class]]) continue;
                        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                        NSError *error;
                        // 先反序列化出字典中key的数组
                        NSArray *nestArray = nil;
                        @try {
                            nestArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                            if (!error)
                            {
                                // 遍历allKeys数据查找对应的嵌套数据, 并赋值给该属性
                                NSMutableDictionary *mulDic = [NSMutableDictionary dictionary];
                                for (id key in nestArray)
                                {
                                    // 拼接查找语句
                                    NSString *nextSelectStr = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@';", info.associateClass, SY_SQLITE_SUPERIOR_TABLE_HEADNODE, [self __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:primaryKey keyOfDict:key]];
                                    
                                    // 调起查询语句(递归调用, 希望得到唯一确定的数据)
                                    NSArray *nestArrResult = [info.associateClass __SY_SelectWithCondition:nextSelectStr database:db rollback:rollback];
                                    if (nestArrResult.count > 0)
                                    {
                                        [mulDic setObject:nestArrResult.firstObject forKey:key];
                                    }
                                }
                                if (mulDic.allKeys.count > 0)
                                {
                                    [model setValue:mulDic forKey:info.name];
                                }
                            }
                        } @catch (NSException *exception) {
                            
                        } @finally {
                            
                        }
                    }
                    else
                    {
                        // 拼接查找语句
                        NSString *nextSelectStr = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@';", info.associateClass, SY_SQLITE_SUPERIOR_TABLE_HEADNODE, [self __SY_GetSuperiorHeadNodeWithPropertyName:info.name primaryKey:primaryKey keyOfDict:nil]];
                        
                        // 调起查询语句(递归调用, 希望得到唯一确定的数据)
                        NSArray *nestArrResult = [info.associateClass __SY_SelectWithCondition:nextSelectStr database:db rollback:rollback];
                        if (nestArrResult.count > 0)
                        {
                            if ([info.ocType isSubclassOfClass:[NSArray class]]) // 数组
                            {
                                [model setValue:nestArrResult forKey:info.name];
                            }
                            else if ([info.ocType isSubclassOfClass:[NSSet class]])
                            {
                                [model setValue:[NSSet setWithArray:nestArrResult] forKey:info.name];
                            }
                            else
                            {
                                [model setValue:nestArrResult.firstObject forKey:info.name];
                            }
                        }
                    }
                }
                else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSDictionary class]] || [info.ocType isSubclassOfClass:[NSSet class]]) // 集合属性(非嵌套)
                {
                    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *error;
                    // 先反序列化出字典中key的数组
                    id objc = nil;
                    @try {
                        objc = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                        if (!error)
                        {
                            [model setValue:objc forKey:info.name];
                        }
                    } @catch (NSException *exception) {
                        
                    } @finally {
                        
                    }
                }
                else if ([info.ocType isSubclassOfClass:[NSDate class]]) // 存储阶段的NSDate类型
                {
                    if (![value isKindOfClass:[NSNumber class]]) continue;
                    NSTimeInterval interval = [value doubleValue];
                    if (interval <= 0) continue;
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
                    if (date) [model setValue:date forKey:info.name];
                }
                // 以NSData形式存储
                else if ([info.ocType isSubclassOfClass:[NSData class]])
                {
                    if (![value isKindOfClass:[NSData class]]) continue;
                    [model setValue:value forKey:info.name];
                }
                else // 其他类型以二进制格式存储
                {
                    // 直接赋值(存储时是以二进制数据存储, 取出并赋值也直接以二进制数据赋值)
                    [model setValue:value forKey:info.name];
                }
            }
            else if (info.variableType == SY_Variable_TYPE_BASEDATA)
            {
                // 基础数据类型
                [model setValue:value forKey:info.name];
            }
            else if (info.variableType == SY_Variable_TYPE_BLOCK)
            {
                // 不存储
            }
            else if (info.variableType == SY_Variable_TYPE_STUCT)
            {
                NSValue *stuctValue = nil;
                // 如果该value实现了拼接后的字符串所表示的方法
                if ([info.stuctName isEqualToString:@"CGRect"])
                {
                    stuctValue = [NSValue valueWithCGRect:CGRectFromString(value)];
                }
                else if ([info.stuctName isEqualToString:@"CGSize"])
                {
                    stuctValue = [NSValue valueWithCGSize:CGSizeFromString(value)];
                }
                else if ([info.stuctName isEqualToString:@"CGPoint"])
                {
                    stuctValue = [NSValue valueWithCGPoint:CGPointFromString(value)];
                }
                if (stuctValue)
                {
                    [model setValue:stuctValue forKey:info.name];
                }
            }
            else if (info.variableType == SY_Variable_TYPE_ID)
            {
                // 直接赋值(存储时是以二进制数据存储, 取出并赋值也直接以二进制数据赋值)
                [model setValue:value forKey:info.name];
            }
        }
        
        // 赋值主键
        model->_primaryKey = primaryKey;
        model->_superiorHeadNode = superiorHeadNode;
        // 将查询结果添加到查询结果数组中
        [resultList addObject:model];
    }
    
    return resultList;
}

#pragma mark- 类方法
/// 谁调起就配置谁的表
/// @param db 数据库操作对象
/// @param rollback 是否回滚
/// @return 返回该表是否已经创建成功或者新增字段成功
+ (BOOL)__SY_ConfigSQLiteTableWithDB:(FMDatabase * _Nonnull)db rollback:(BOOL * _Nonnull)rollback
{
    BOOL result = YES;
    if ([instanceClasses containsObject:NSStringFromClass(self)]) return result;
    instanceClasses = [NSMutableArray arrayWithArray:instanceClasses];
    [instanceClasses addObject:NSStringFromClass(self)];
    
    // 2.查询以当前类为表名的数据库表是否已经存在
    BOOL isExist = [db tableExists:NSStringFromClass(self)];

    if (isExist)
    {
        NSLog(@"[%@]表已存在无需创建", NSStringFromClass([self class]));
        // 表已存在的情况下, 判断是否需要更新表内容
        NSMutableArray *columnNames = [NSMutableArray array];

        // 根据数据库对象获取指定表的信息
        FMResultSet *resultSet = [db getTableSchema:NSStringFromClass(self)];
        while ([resultSet next]) {
            NSString *columnName = [resultSet stringForColumn:@"name"];
            [columnNames addObject:columnName];
        }

        // 获取可以存储的属性列表字典
        NSDictionary *storeDic = [self __SY_CacheEnablePropertyInfo];
        // 取出所有属性名
        NSArray *propertyNameList = storeDic.allKeys;

        // 数据库中取出的列名数组集合范围小, 而属性名数组集合范围大, 所以需要求得在大集合但没有在小集合中的部分
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
        NSArray *needSavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];

        // 表示有需要新增到数据库中的字段
        if (!needSavedProperties || needSavedProperties.count == 0) return result;

        // 挨个找到属性信息对象插入新的列名
        for (NSString *columnName in needSavedProperties)
        {
            SYPropertyInfo *p = storeDic[columnName];

            NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", NSStringFromClass(self), columnName, p.cacheTypeInSQL];
            BOOL success = [db executeUpdate:sqlString];
            if (success)
            {
                NSLog(@"[%@]表增加字段成功语句为:(%@)", NSStringFromClass(self), sqlString);
            }
            else
            {
                NSLog(@"[%@]表增加字段失败语句为:(%@)", NSStringFromClass(self), sqlString);
                *rollback = YES; return NO;
            }
        }
    }
    else
    {
        // 3.按SQL语句格式拼接属性组成的字符串
        NSString *propertySQLString = [self __SY_GetPropertyNameAndSQLiteTypeStringWhileCreateTable];

        if ([propertySQLString isEqualToString:@""])
        {
            NSAssert(NO, @"未添加任何需保存的属性");
            *rollback = YES; return NO;
        }

        // 4.关联表配置(嵌套属性引起的)
        NSString *associatedColumn = [NSString stringWithFormat:@"%@ %@", SY_SQLITE_SUPERIOR_TABLE_HEADNODE, @"TEXT"];

        // 5.组合主键
        NSString *primaryKey = [NSString stringWithFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT", SY_SQLITE_PRIMARY_KEY];

        // 6.将主键、各属性糅合成sql命令(主键、关联表字段、各属性)
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@,%@,%@);", NSStringFromClass(self), primaryKey, associatedColumn, propertySQLString];

        // 7.执行该命令, 得出是否创建表成功
        BOOL isSuccess = [db executeUpdate:sql];
        if (!isSuccess)
        {
            NSLog(@"[%@]表创建失败语句为:(%@)", NSStringFromClass(self), sql);
            *rollback = YES; return NO;
        }
        else
        {
            NSLog(@"[%@]表创建成功语句为:(%@)", NSStringFromClass(self), sql);
        }
    }
    return result;
}

/// 拼接调用者类创建表时属性名及在sql中的类型组成的SQL语句
+ (NSString *)__SY_GetPropertyNameAndSQLiteTypeStringWhileCreateTable
{
    NSMutableString *str = [NSMutableString string];
    // 1.取出可以存储的属性字典
    NSDictionary *dic = [self __SY_CacheEnablePropertyInfo];
    
    // 2.遍历该字典后将每个属性的名称以及在sqlite中应该保存的格式类型拼接起来
    for (SYPropertyInfo *p in dic.allValues)
    {
        [str appendFormat:@"%@ %@,", p.name, p.cacheTypeInSQL];
    }
    
    if ([str hasSuffix:@","])
    {
        [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
    }
    
    return str.copy;
}

/// 获取整个条件语句中自where开始的后半段
/// @param condition 条件语句
+ (NSString *)__SY_GetTheStringAfterTheTableNameWithCondition:(NSString *)condition
{
    // 0.判断condition是否为nil或不是字符串
    if (!condition || ![condition isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@" WHERE %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    // 1.替换最后的分号
    condition = [condition stringByReplacingOccurrencesOfString:@";" withString:@""];
    
    // 2.首位拼接一个空格并用小写形式来获取其中where字符串的范围
    NSRange range = [[[@" " stringByAppendingString:condition] lowercaseString] rangeOfString:@" where "];
    
    // 3.判断该字符串中是否存在where, 也就是条件语句
    if (range.location == NSNotFound) return [NSString stringWithFormat:@" WHERE %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    // 4.裁剪where之后
    condition = [condition substringFromIndex:range.location];
    
    // 5.判断该语句中是否存在上级结点
    NSRange headNodeRange = [[[@" " stringByAppendingString:condition] lowercaseString] rangeOfString:[[NSString stringWithFormat:@" %@ ", SY_SQLITE_SUPERIOR_TABLE_HEADNODE] lowercaseString]];
    
    // 6.如果不存在上级结点, 则拼接结点为null进行返回
    if (headNodeRange.location == NSNotFound) return [condition stringByAppendingString:[NSString stringWithFormat:@" AND %@ IS NULL;", SY_SQLITE_SUPERIOR_TABLE_HEADNODE]];
    
    // 7.如果存在结点, 则对分好;进行容错范围
    return [[condition stringByReplacingOccurrencesOfString:@";" withString:@""] stringByAppendingString:@";"];
}

/// 防止SQLite语句中的通配符失效, like语句有效
/// @param string 原句
+ (NSString *)__SY_SQLiteStringBeforeAppendWildcardOfString:(NSString *)string
{
    // 只转义like后面的字段
    NSString *right = [string lowercaseString];
    NSRange range = [right rangeOfString:@" like "];
    if (range.location == NSNotFound) return string;
    
    // 裁剪
    NSString *left = [string substringToIndex:range.location];
    right = [string substringFromIndex:range.location];
    
    // 2.中括号[]
    // []：表示括号内所列字符中的一个（类似正则表达式）。指定一个字符、字符串或范围，要求所匹配的对象为他们中的任一个。
    // [^]：表示不在括号所列之内的单个字符。其取之和[]相同，但它所要求匹配对象为指定字符以外的任一个字符。
    right = [right stringByReplacingOccurrencesOfString:@"[" withString:@"[[]"];
    // 1.下划线_  _:表示任意单个字符。匹配单个任意字符，它常用来限制表达式的字符长度：
    right = [right stringByReplacingOccurrencesOfString:@"_" withString:@"[_]"];
    // 3.百分号%  %：表示零个或多个字符。
    right = [right stringByReplacingOccurrencesOfString:@"%" withString:@"[%]"];
    
    // 拼接起来
    return [left stringByAppendingString:right];
}

/// 获取与上级表关联的头结点, 调用者类作为上级表名
/// @param name 下级表数据关联的上级表数据的属性名
/// @param primaryKey 下级表关联的上级表数据的主键
/// @param key 下级表关联的上级表属性为字典时需标明所关联的key(在字典中key肯定不为nil)
+ (NSString *)__SY_GetSuperiorHeadNodeWithPropertyName:(NSString *)name primaryKey:(long long)primaryKey keyOfDict:(id)key
{
    NSString *result = [NSString stringWithFormat:@"%@%@%@%@%lld", NSStringFromClass(self), SY_SQLITE_SPLIT_KEY, name, SY_SQLITE_SPLIT_KEY, primaryKey];
    if (key && ![key isKindOfClass:[NSNull class]]) {
        Class keyClass = [key class];
        Class baseClass = keyClass;
        // 找出key的最基层类型
        while (keyClass != [NSObject class]) {
            baseClass = keyClass;
            keyClass = [keyClass superclass];
        }
        result = [result stringByAppendingFormat:@"%@%@%@%@", SY_SQLITE_SPLIT_KEY, NSStringFromClass(baseClass),SY_SQLITE_SPLIT_KEY, key];
    }
    return result;
}

#pragma mark- 实例方法

/// 获取调用者对象的可序列化可存储的嵌套数据的值
/// @param info 属性信息对象
- (id)__SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:(SYPropertyInfo *)info
{
    id valueOfProperty = [self valueForKey:info.name];
    
    // 3.不存储或不嵌套返回空
    if (!info.cacheEnable || !info.associateClass) return nil;
    
    // 4.取得该属性的值
    if (!valueOfProperty || [valueOfProperty isKindOfClass:[NSNull class]]) return nil;
    
    // 5.判定该嵌套属性信息的OC类型(集合类型只嵌套一层, 不支持多层套娃)
    if ([info.ocType isSubclassOfClass:[NSDictionary class]]) // 字典类型
    {
        // 6.先判断值本身是否为字典, 如果不是字典, 不做存储与更新并给予提示
        if (![valueOfProperty isKindOfClass:[NSDictionary class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        // 7.如果值是字典, 则遍历并剔除不符合格式的key与value
        NSMutableDictionary *mul = [NSMutableDictionary dictionary];
        for (id keyOfDic in [valueOfProperty allKeys])
        {
            if (![keyOfDic __SY_RemoveCannotSerializationPart]) continue;
            id valueOfDic = [valueOfProperty objectForKey:keyOfDic];
            if (![valueOfDic isKindOfClass:info.associateClass]) continue;
            [mul setObject:valueOfDic forKey:keyOfDic];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:[NSArray class]]) // 数组
    {
        // 12.先判断值本身是否为数组, 如果不是数组, 不做存储与更新并给予提示
        if (![valueOfProperty isKindOfClass:[NSArray class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        // 13.遍历并剔除不符合格式的value
        NSMutableArray *mul = [NSMutableArray array];
        for (id valueOfArr in valueOfProperty)
        {
            if (![valueOfArr isKindOfClass:info.associateClass]) continue;
            [mul addObject:valueOfArr];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:[NSSet class]]) // 集合
    {
        // 15.先判断值本身是否为集合, 如果不是集合, 不做存储与更新并给予提示
        if (![valueOfProperty isKindOfClass:[NSSet class]])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        // 16.遍历并剔除不符合格式的value
        NSMutableSet *mul = [NSMutableSet set];
        for (id valueOfArr in valueOfProperty)
        {
            if (![valueOfArr isKindOfClass:info.associateClass]) continue;
            [mul addObject:valueOfArr];
        }
        
        return mul;
    }
    else if ([info.ocType isSubclassOfClass:info.associateClass]) // 直接嵌套
    {
        // 18.先判断值本身是否为嵌套类, 如果不是, 不做存储与更新并给予提示
        if (![valueOfProperty isKindOfClass:info.associateClass])
        {
            NSAssert(NO,[NSString stringWithFormat:@"值与声明的类型不一致"]);
            return nil;
        }
        
        return valueOfProperty;
    }
    
    return nil;
}

/// 配置调用者对象的可存储属性信息组合成的SQL语句(插入更新专用)
/// @param superiorHeadNode 上级头结点字段值是否为null
/// @param completionHandler 配置完成后返回(1.属性名组成的字符串、2.属性值为?或null组成的字符串、3.属性非null时对应的value数组)
- (void)__SY_ConfigSQLiteStringOfCacheEnablePropertiesWithSuperiorHeadNode:(NSString *)superiorHeadNode completionHandler:(void(^)(NSString *cacheEnablePropertyNameSQLiteString, NSString *cacheEnablePropertySignSQLiteString, NSString *cacheEnablePropertyNameAndSign, NSArray *cacheEnablePropertyValues))completionHandler
{
    // 1.取出需要存储的属性集合
    NSDictionary *cacheDic = [[self class] __SY_CacheEnablePropertyInfo];
    
    // 3.可存储属性名组成的字符串
    NSMutableString *cacheEnablePropertyNameSQLiteString = [NSMutableString string];
    
    // 4.可存储属性标志值组成的字符串
    NSMutableString *cacheEnablePropertySignSQLiteString = [NSMutableString string];
    
    // 5.可存储属性值组成的数组
    NSMutableArray *cacheEnablePropertyValues = [NSMutableArray array];
    
    // 属性名与标志的结合
    NSMutableString *cacheEnablePropertyNameAndSign = [NSMutableString string];
    
    // 6.配置嵌套用的关联上级表的字段
    [cacheEnablePropertyNameSQLiteString appendFormat:@"%@,", SY_SQLITE_SUPERIOR_TABLE_HEADNODE];
    
    // 7.上级头结点是否存在, 存在则值标志为(?,)并添加该属性的值到数组中备用, 不存在则值标志为(null,)
    if (superiorHeadNode)
    {
        [cacheEnablePropertySignSQLiteString appendFormat:@"?,"];
        [cacheEnablePropertyValues addObject:superiorHeadNode];
    }
    else
    {
        [cacheEnablePropertySignSQLiteString appendFormat:@"null,"];
    }
    
    [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@,", SY_SQLITE_SUPERIOR_TABLE_HEADNODE, superiorHeadNode ? @"?" : @"null"];
    
    // 8.遍历可存储属性信息字典
    for (SYPropertyInfo *info in cacheDic.allValues)
    {
        // 9.取出该属性的值, 并配置属性名到可变字符串中
        id value = [self valueForKey:info.name];
        [cacheEnablePropertyNameSQLiteString appendFormat:@"%@,", info.name];
        if (!value || [value isKindOfClass:[NSNull class]])
        {
            [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@,", info.name, @"null"];
            [cacheEnablePropertySignSQLiteString appendString:@"null,"];continue;
        }
        
        // 10.设一个中间值来接收可存储值标志
        NSString *sign = @"null,";
        
        // 11.判断变量的类型
        if (info.variableType == SY_Variable_TYPE_UNKNOW) // 未知类型
        {
            // 不予存储
        }
        else if (info.variableType == SY_Variable_TYPE_OBJECTC) // OC对象
        {
            // 12.如果为嵌套类(分为数组、字典、集合、直接嵌套)上级头结点值分别存储(null,json序列化字符串,null,null)
            if (info.associateClass)
            {
                if ([info.ocType isSubclassOfClass:[NSDictionary class]])
                {
                    // 13.判定属性值是否为字典, 并取出字典中的所有key数组, 将该数组进行序列化得到JSON字符串
                    if ([value isKindOfClass:[NSDictionary class]])
                    {
                        // 14.剔除其中第一级不是嵌套的key
                        NSDictionary *mul = [self __SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:info];
                        NSArray *allKeys = [mul allKeys];
                        NSError *error = nil; NSData *data = nil;
                        @try { // 有可能序列化失败
                            data = [NSJSONSerialization dataWithJSONObject:allKeys options:NSJSONWritingPrettyPrinted error:&error];
                            if (!error) {
                                NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                sign = @"?,";
                                [cacheEnablePropertyValues addObject:jsonStr];
                            }
                        } @catch (NSException *e) {}
                    }
                }
            }
            // 14.非嵌套类型的OC对象, 是集合类型, 剔除其中不能存储的部分进行序列化, 并存储序列化后的JSON字符串
            else if ([info.ocType isSubclassOfClass:[NSArray class]] || [info.ocType isSubclassOfClass:[NSDictionary class]] || [info.ocType isSubclassOfClass:[NSSet class]])
            {
                // 15.将不适合序列化的部分剔除
                value = [value __SY_RemoveCannotSerializationPart];
                
                NSError *error = nil; NSData *data = nil;
                @try { // 有可能序列化失败
                    data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                    if (!error) {
                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        sign = @"?,";
                        [cacheEnablePropertyValues addObject:jsonStr];
                    }
                } @catch (NSException *e) {}
            }
            // 16.配置OC类型中的NSDate类型
            else if ([info.ocType isSubclassOfClass:[NSDate class]]) // 存储阶段的NSDate类型
            {
                if ([value isKindOfClass:[NSDate class]])
                {
                    // 转换为时间戳模式(以秒为单位)
                    NSTimeInterval interval = [value timeIntervalSince1970];
                    
                    [cacheEnablePropertyValues addObject:[NSNumber numberWithDouble:interval]];
                    sign = @"?,";
                }
            }
            else if ([info.ocType isSubclassOfClass:[NSNumber class]])
            {
                if ([value isKindOfClass:[NSNumber class]])
                {
                    [cacheEnablePropertyValues addObject:value];
                    sign = @"?,";
                }
            }
            // 如果是二进制数据类型的, 则存储
            else if ([info.ocType isSubclassOfClass:[NSData class]])
            {
                if ([value isKindOfClass:[NSData class]])
                {
                    [cacheEnablePropertyValues addObject:value];
                    sign = @"?,";
                }
            }
            // 17.其他OC类型以二进制格式存储
            else
            {
                // 不予存储
            }
        }
        // 18.基础数据类型
        else if (info.variableType == SY_Variable_TYPE_BASEDATA)
        {
            [cacheEnablePropertyValues addObject:value];
            sign = @"?,";
        }
        // 19.block类型
        else if (info.variableType == SY_Variable_TYPE_BLOCK)
        {
            
        }
        // 20.结构体类型
        else if (info.variableType == SY_Variable_TYPE_STUCT)
        {
            NSString *sel = [info.stuctName stringByAppendingString:@"Value"];
            // 如果该value实现了拼接后的字符串所表示的方法
            if ([value respondsToSelector:NSSelectorFromString(sel)])
            {
                NSString *stuctToString = nil;
                if ([info.stuctName isEqualToString:@"CGRect"])
                {
                    stuctToString = NSStringFromCGRect([value CGRectValue]);
                }
                else if ([info.stuctName isEqualToString:@"CGPoint"])
                {
                    stuctToString = NSStringFromCGPoint([value CGPointValue]);
                }
                else if ([info.stuctName isEqualToString:@"CGSize"])
                {
                    stuctToString = NSStringFromCGSize([value CGSizeValue]);
                }
                if (stuctToString)
                {
                    [cacheEnablePropertyValues addObject:stuctToString];
                    sign = @"?,";
                }
            }
            // 非CGRect、CGPoint、CGSize时
            else
            {
                
            }
        }
        // id类型, 按二进制存储
        else if (info.variableType == SY_Variable_TYPE_ID)
        {
            // 不予存储
        }

        // 21.拼接字段
        [cacheEnablePropertyNameAndSign appendFormat:@"%@=%@", info.name, sign];
        [cacheEnablePropertySignSQLiteString appendString:sign];
    }
            
    // 22.清除最后一个逗号
    if (cacheEnablePropertyNameSQLiteString.length > 0)
    {
        [cacheEnablePropertyNameSQLiteString deleteCharactersInRange:NSMakeRange(cacheEnablePropertyNameSQLiteString.length - 1, 1)];
    }
    if (cacheEnablePropertySignSQLiteString.length > 0)
    {
        [cacheEnablePropertySignSQLiteString deleteCharactersInRange:NSMakeRange(cacheEnablePropertySignSQLiteString.length - 1, 1)];
    }
    if (cacheEnablePropertyNameAndSign.length > 0)
    {
        [cacheEnablePropertyNameAndSign deleteCharactersInRange:NSMakeRange(cacheEnablePropertyNameAndSign.length - 1, 1)];
    }
    
    // 23.调起block回调
    if (completionHandler) {
        completionHandler(cacheEnablePropertyNameSQLiteString, cacheEnablePropertySignSQLiteString, cacheEnablePropertyNameAndSign, cacheEnablePropertyValues);
    }
}

/// 处理可存储嵌套属性的值使之可以序列化 操作嵌套数据并推动递归操作
/// @param operation 推进递归操作的block
- (void)__SY_HandleNestDataWithRecursionOperation:(void(^)(SYPropertyInfo *info, id recursionValue))operation
{
    // 1.获取当前对象所属类的所有嵌套属性信息字典
    NSDictionary *nestDic = [self.class __SY_NestPropertyInfo];
    
    // 2.遍历该嵌套属性信息字典
    for (SYPropertyInfo *info in nestDic.allValues)
    {
        // 3.判定是否为可存储类型, 非可存储类型不走逻辑
        if (!info.cacheEnable) continue;
        
        id recursionValue = [self __SY_GetSerializableNestValueOfCallerObjectWithPropertyInfo:info];
        
        if (operation) operation(info, recursionValue);
    }
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return self;
}

- (void)dealloc
{
    NSLog(@"%@已销毁", NSStringFromClass([self class]));
}

@end
