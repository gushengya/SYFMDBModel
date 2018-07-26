//
//  NSObject+SY_FMDBExtension.m
//  
//
//  Created by 谷胜亚 on 2018/6/22.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "NSObject+SY_FMDBExtension.h"
#import <objc/runtime.h>
#import "SY_Property.h"
#import "SY_FMDBManager.h"
#import <UIKit/UIKit.h>
#import "SY_Error.h"

/// 数据库中每个表的头结点值分割符: [嵌套父级类名+分隔符+所属属性名+分隔符+嵌套父级在数据库中的主键]组成头链
#define SY_SING_HEADNODE @"_SY_"

/// 关联的主键
static const char SY_ASSOCIATED_PRIMARYKEY;

#pragma mark- <-----------  属性分类列表  ----------->
/// 关联的全部属性模型集合
static const char SY_ASSOCIATED_ALLPROPERTY;
/// 关联的可持久化属性模型集合 -- 不包含嵌套属性
static const char SY_ASSOCIATED_SAVEPROPERTY;
/// 关联的嵌套属性模型集合
static const char SY_ASSOCIATED_NESTPROPERTY;

#pragma mark- <-----------  数据库表中设计的列名  ----------->
/// 头结点(包含了所属嵌套对象的信息)
static NSString *const SY_COLUMNNAME_HEADNODE = @"SY_COLUMNNAME_HEADNODE";

/// 主键自增(从1开始)
static NSString *const SY_COLUMNNAME_KEYWORD = @"SY_COLUMNNAME_KEYWORD";




@implementation NSObject (SY_FMDBExtension)

/// 合法的结构体类型
+ (NSArray *)sy_LegalStructTypes
{
    return @[@"CGPoint", @"CGSize", @"CGRect"];
}

#pragma mark- <-----------  配置属性以及数据库表  ----------->
/// 配置该类继承关系数上属性列表信息
+ (void)sy_ConfigProperties
{
    if (!objc_getAssociatedObject(self, &SY_ASSOCIATED_ALLPROPERTY)) // 没有值,为NULL
    {
        [self sy_InspectProperty];

        [self sy_ConfigSQLTable];
        
        NSDictionary *nest = objc_getAssociatedObject(self, &SY_ASSOCIATED_NESTPROPERTY);
        for (SY_Property *p in nest.allValues) {
            [p.associateClass sy_ConfigProperties];
        }
    }
}

/// 配置SQL表的信息
+ (void)sy_ConfigSQLTable
{
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {

        BOOL isExist = [db tableExists:NSStringFromClass(self)];
        if (isExist) {
            NSLog(@"[SY_Error]%@表已存在无需创建", NSStringFromClass([self class]));
        }else {
            // 按SQL语句格式拼接属性组成的字符串
            NSString *propertySQLString = [self sy_SplicingSqlString];
            
            if ([propertySQLString isEqualToString:@""]) {
                NSAssert(NO, @"未添加任何需保存的属性");
                *rollback = YES; return ;
            }
            
            NSString *associatedColumn = [NSString stringWithFormat:@"%@ %@", SY_COLUMNNAME_HEADNODE, @"TEXT"];
            
            NSString *primaryKey = [NSString stringWithFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT", SY_COLUMNNAME_KEYWORD];
            
            NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@,%@,%@);", NSStringFromClass(self), primaryKey,  associatedColumn, propertySQLString];
            
            BOOL isSuccess = [db executeUpdate:sql];
            
            if (isSuccess == NO) {
                NSLog(@"[SY_Error]%@表创建失败语句为:(%@)", NSStringFromClass(self), sql);
                *rollback = YES; return;
            }
            
            NSLog(@"[SYFMDBModel]%@表创建成功语句为:(%@)", NSStringFromClass(self), sql);
        }
        
        // 3. 表已存在的情况下, 判断是否需要更新表内容
        NSMutableArray *columnNames = [NSMutableArray array];
        
        // 根据数据库对象获取指定表的信息
        FMResultSet *resultSet = [db getTableSchema:NSStringFromClass(self)];
        while ([resultSet next]) {
            NSString *columnName = [resultSet stringForColumn:@"name"];
            [columnNames addObject:columnName];
        }
        
        NSDictionary *storeDic = objc_getAssociatedObject(self, &SY_ASSOCIATED_SAVEPROPERTY);
        NSArray *propertyNameList = storeDic.allKeys;
        
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];

        NSArray *needSavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
        
        if (needSavedProperties.count > 0)
        {
            for (NSString *columnName in needSavedProperties)
            {
                SY_Property *p = storeDic[columnName];
                
                NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", NSStringFromClass(self), columnName, p.sqlTypeName];
                BOOL success = [db executeUpdate:sqlString];
                if (success)
                {
                    NSLog(@"[SYFMDBModel]%@表增加字段成功语句为:(%@)", NSStringFromClass(self), sqlString);
                }
                else
                {
                    NSLog(@"[SY_Error]%@表增加字段失败语句为:(%@)", NSStringFromClass(self), sqlString);
                    *rollback = YES; return;
                }
            }
        }
        else
        {
            
        }
    }];
}

/// 检验属性信息
+ (void)sy_InspectProperty
{
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    NSMutableDictionary *store = [NSMutableDictionary dictionary];
    NSMutableDictionary *nest = [NSMutableDictionary dictionary];
    
    NSScanner *scanner = nil; NSString *type = nil; Class class = self;
    
    while (class != NSObject.class) {
        unsigned int count;
        objc_property_t *list = class_copyPropertyList(class, &count);
        
        NSDictionary *nestMap = [class sy_nestPropertyMapList];
        
        for (unsigned int i = 0; i < count; i++)
        {
            SY_Property *des = [[SY_Property alloc] init];
            
            objc_property_t property = list[i];
            
            NSString *name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            des.name = name;
            
            NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
            NSArray *keywords = [attributes componentsSeparatedByString:@","];
            
            if ([keywords containsObject:@"R"]) {des.isReadOnly = YES; des.isIgnore = YES;}
            
            scanner = [NSScanner scannerWithString:attributes];
            
            [scanner scanUpToString:@"T" intoString:nil];
            [scanner scanString:@"T" intoString:nil];
            
            if ([scanner scanString:@"@\"" intoString:&type])
            {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&type];
                
                if ([type isEqualToString:@""])
                {
                    des.unObjectCType = SYNotObjectCType_IdOfProtocol;
                    des.isIgnore = YES;
                }
                else
                {
                    des.ocType = NSClassFromString(type);
                    des.isMutable = ([type rangeOfString:@"Mutable"].location != NSNotFound);
                    
                    if ([des.ocType isSubclassOfClass:[NSString class]])
                    {
                        des.sqlTypeName = @"TEXT";
                    }
                    else if ([des.ocType isSubclassOfClass:[NSNumber class]])
                    {
                        des.sqlTypeName = @"REAL";
                    }
                    else if ([des.ocType isSubclassOfClass:[NSDate class]])
                    {
                        des.sqlTypeName = @"REAL";
                    }
                    else
                    {
                        des.sqlTypeName = @"BLOB";
                    }
                }
                
                NSString *protocolName = nil;
                while ([scanner scanString:@"<" intoString:nil])
                {
                    [scanner scanUpToString:@">" intoString:&protocolName];
                    
                    if ([protocolName isEqualToString:@"SY_Store"])
                    {
                        des.isSave = YES;
                    }
                    else
                    {
                        if (des.protocolNameList != nil) {
                            [des.protocolNameList addObject:protocolName];
                        }else {
                            des.protocolNameList = [NSMutableArray arrayWithObject:protocolName];
                        }
                    }
                    
                    [scanner scanString:@">" intoString:nil];
                }
            }
            
            else if ([scanner scanString:@"@?" intoString:nil])
            {
                des.unObjectCType = SYNotObjectCType_Block;
                des.isIgnore = YES;
            }
            else if ([scanner scanString:@"@" intoString:nil])
            {
                des.unObjectCType = SYNotObjectCType_Id;
                des.isIgnore = YES;
            }
            else if ([scanner scanString:@"{" intoString:&type])
            {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"="] intoString:&type];
                des.unObjectCType = SYNotObjectCType_Stuct;
                des.isIgnore = YES;
                
                if ([[self sy_LegalStructTypes] containsObject:type]) {
                    des.isIgnore = NO;
                    des.stuctName = type;
                    des.sqlTypeName = @"TEXT";
                }
            }
            else
            {
                [scanner scanUpToString:@"," intoString:&type];
                [self sy_SetupPropertyTypeTo:des WithType:type];
                des.unObjectCType = SYNotObjectCType_BaseData;
            }
            
            if ([class respondsToSelector:@selector(sy_savedPropertyName:)] && [class sy_savedPropertyName:des.name]) {
                des.isSave = YES;
            }
            
            if ([nestMap.allKeys containsObject:des.name])
            {
                NSString *className = [nestMap objectForKey:des.name];
                if (className && [className isKindOfClass:[NSString class]])
                {
                    Class nestClass = NSClassFromString(className);
                    
                    if (nestClass) {
                        des.associateClass = nestClass;
                    }else {
                        NSLog(@"[SY_Error]%@类对应的属性%@其类型%@不是OC类型", NSStringFromClass(class), des.name, className);
                        NSAssert(NO, @"");
                    }
                }
                else
                {
                    NSLog(@"[SY_Error]%@类对应的属性%@其类型不是OC类型", NSStringFromClass(class), des.name);
                    NSAssert(NO, @"");
                }
            }
            
            if (des && ![all objectForKey:des.name])
            {
                [all setValue:des forKey:des.name];
                
                if (des.isSave && ![store objectForKey:des.name] && !des.isIgnore)
                {
                    if (des.associateClass != nil && ![nest objectForKey:des.name])
                    {
                        [nest setValue:des forKey:des.name];
                    }else
                    {
                        [store setValue:des forKey:des.name];
                    }
                }
            }
        }
        
        free(list);
        class = [class superclass];
    }
    
    objc_setAssociatedObject(self, &SY_ASSOCIATED_ALLPROPERTY, all, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &SY_ASSOCIATED_SAVEPROPERTY, store, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &SY_ASSOCIATED_NESTPROPERTY, nest, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/// 拼接创建表时属性组成的SQL语句
+ (NSString *)sy_SplicingSqlString
{
    NSMutableString *str = [NSMutableString string];
    NSDictionary *dic = objc_getAssociatedObject(self, &SY_ASSOCIATED_SAVEPROPERTY);
    for (SY_Property *p in dic.allValues) {
        
        [str appendFormat:@"%@ %@,", p.name, p.sqlTypeName];
    }
    
    if ([str hasSuffix:@","]) {
        [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
    }
    
    return str.copy;
}

+ (void)sy_SetupPropertyTypeTo:(SY_Property *)p WithType:(NSString *)type
{
    if ([type isEqualToString:@"q"]) // int64位类型、long类型、longlong类型
    {
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"int64_t";
    }
    else if ([type isEqualToString:@"i"]) // int32位类型、int类型
    {
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"int32_t";
    }
    else if ([type isEqualToString:@"s"]) // int16位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"int16_t";
    }
    else if ([type isEqualToString:@"c"]) // int8位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"int8_t";
    }
    else if ([type isEqualToString:@"f"]) // 单精度float类型
    {
        p.sqlTypeName = @"REAL";
        p.baseDataName = @"float";
    }
    else if ([type isEqualToString:@"d"]) // 双精度double类型、双精度CGFloat
    {
        p.sqlTypeName = @"REAL";
        p.baseDataName = @"double";
    }
    else if ([type isEqualToString:@"B"]) // BOOL类型
    {
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"BOOL";
    }
    else { // 其他类型
        p.sqlTypeName = @"INTEGER";
        p.baseDataName = @"int";
    }
}

#pragma mark- <-----------  可由类重写的方法  ----------->
/// 保存的属性名
+ (BOOL)sy_savedPropertyName:(NSString *)name
{
    return NO;
}

/// 嵌套属性映射 -- key为属性名, value为嵌套的类名(NSString)
+ (NSDictionary<NSString*, NSString*> *)sy_nestPropertyMapList
{
    return nil;
}

/// 类中属性名与表中字段名的映射
+ (NSDictionary<NSString*, NSString*> *)sy_propertyColumnMapList
{
    return nil;
}

#pragma mark- <-----------  数据库操作  ----------->
// FIXME: 新增
/// 增 -- 哪怕保存的是已经添加到数据库中的数据也可以再次插入到数据库中形成一条新的数据(不按主键id来判定是否可以存储)
- (BOOL)sy_InsertWithError:(NSError *__autoreleasing*)error
{
    [self.class sy_ConfigProperties];
    
    // 2. 数据库中进行操作
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self sy_InsertWithHeadNode:nil database:db rollback:rollback error:error];
    }];
    
    return result;
}


/**
 *  递归的方式将模型及其嵌套模型存储到数据库中
 *
 *  @param headNode 关联上级嵌套模型的头结点
 *
 *  @return 返回是否插入成功
 */
- (BOOL)sy_InsertWithHeadNode:(NSString *)headNode database:(FMDatabase *)db rollback:(BOOL *)rollback error:(NSError **)error
{
    NSDictionary *dic = objc_getAssociatedObject([self class], &SY_ASSOCIATED_SAVEPROPERTY);
    NSDictionary *nestdic = objc_getAssociatedObject([self class], &SY_ASSOCIATED_NESTPROPERTY);
    
    NSMutableString *columnList = [NSMutableString string];
    NSMutableString *valueList = [NSMutableString string];
    NSMutableArray *values = [NSMutableArray array];
    
    [columnList appendFormat:@"%@,", SY_COLUMNNAME_HEADNODE];
    if (headNode)
    {
        [valueList appendFormat:@"?,"];
        [values addObject:headNode];
    }
    else
    {
        [valueList appendFormat:@"null,"];
    }
    
    for (NSString *key in dic.allKeys) {
        SY_Property *p = dic[key];
        
        id value = [self valueForKey:p.name];
        [columnList appendFormat:@"%@,", p.name];
        if (value == nil || [value isEqual:[NSNull null]]) // 空值
        {
            [valueList appendFormat:@"null,"];
        }
        else
        {
            [valueList appendFormat:@"?,"];
            
            if (p.ocType != nil && ![p.ocType isSubclassOfClass:[NSNull class]])
            {
                if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSDictionary class]]) // 集合
                {
                    NSError *error = nil; NSData *data = nil;
                    @try { // 有可能序列化失败
                        data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                        if (!error) {
                            NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            [values addObject:jsonStr];
                        }else {
                            [values addObject:value];
                        }
                    }
                    @catch (NSException *e) {
                        [values addObject:value];
                    }
                    
                }
                else if ([p.ocType isSubclassOfClass:[NSDate class]]) // 存储阶段的NSDate类型
                {
                    if (![value isKindOfClass:[NSDate class]]) {
                        NSString *key = [NSString stringWithFormat:@"(insert)%@类的%@非嵌套属性类型为%@但KVC取值得到类型为%@", NSStringFromClass([self class]), p.name, NSStringFromClass(p.ocType), NSStringFromClass([value class])];
                        NSLog(@"[SY_Error]%@", key);
                        if (error) {
                            *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE
                                                         code:SY_ERRORTYPE_INSERT_NO1
                                                     userInfo:@{NSLocalizedDescriptionKey:key}];
                        }
                        *rollback = YES; return NO;
                    }
                    
                    NSTimeInterval interval = [value timeIntervalSince1970];
                    
                    [values addObject:[NSNumber numberWithDouble:interval]];
                }
                else
                {
                    [values addObject:value];
                }
            }
            else if (p.unObjectCType == SYNotObjectCType_Stuct && p.stuctName) // 结构体
            {
                if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
                {
                    CGPoint point = CGPointZero;
                    @try {
                        point = [value CGPointValue];  // CGPoint等结构体在使用KVC获取的时候自动打包成NSValue值, 需使用NSValue类对应实例方法取得原值
                    }@catch (NSException *e) {
                        
                    }
                    
                    [values addObject:NSStringFromCGPoint(point)];
                }
                else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
                {
                    CGSize size = CGSizeZero;
                    @try {
                        size = [value CGSizeValue];
                    }@catch (NSException *e) {
                        
                    }
                    
                    [values addObject:NSStringFromCGSize(size)];
                }
                else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
                {
                    CGRect rect = CGRectZero;
                    @try {
                        rect = [value CGRectValue];
                    }@catch (NSException *e) {
                        
                    }
                    
                    [values addObject:NSStringFromCGRect(rect)];
                }
                else
                {
                    [values addObject:value];
                }
            }
            else
            {
                [values addObject:value];
            }
        }
    }
    
    // 清除最后一个逗号
    if (columnList.length > 0) {
        [columnList deleteCharactersInRange:NSMakeRange(columnList.length - 1, 1)];
    }
    if (valueList.length > 0) {
        [valueList deleteCharactersInRange:NSMakeRange(valueList.length - 1, 1)];
    }
    
    NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", NSStringFromClass([self class]), columnList, valueList];
    
    BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:values];
    if (isSuccess)
    {
        int64_t pkID = db.lastInsertRowId;
        
        for (NSString *key in nestdic.allKeys)
        {
            SY_Property *p = nestdic[key];
            
            NSString *associatedColumnValue = [NSString stringWithFormat:@"%@%@%@%@%lld", NSStringFromClass(self.class), SY_SING_HEADNODE, p.name, SY_SING_HEADNODE, pkID];
            
            id value = [self valueForKey:p.name];
            
            if (value == nil || [value isKindOfClass:[NSNull class]]) continue;
            
            if ([p.ocType isSubclassOfClass:[NSArray class]])
            {
                if (![value isKindOfClass:[NSArray class]])
                {
                    NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的%@嵌套属性类型为%@但KVC取值得到类型为%@", NSStringFromClass([self class]), p.name, NSStringFromClass(p.ocType), NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE
                                                     code:SY_ERRORTYPE_INSERT_NO2
                                                 userInfo:@{NSLocalizedDescriptionKey:logKey}];
                    }
                    *rollback = YES; return NO;
                }
                
                for (id subValue in value)
                {
                    if ([subValue isKindOfClass:p.associateClass])
                    {
                        if (![subValue sy_InsertWithHeadNode:associatedColumnValue database:db rollback:rollback error:error]) {
                            return NO;
                        }
                    }
                    else
                    {
                        NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的%@嵌套集合属性声明嵌套类为%@但KVC取值得到其子值类型为%@", NSStringFromClass([self class]), p.name, NSStringFromClass(p.associateClass), NSStringFromClass([subValue class])];
                        NSLog(@"[SY_Error]%@", logKey);
                        if (error) {
                            *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE
                                                         code:SY_ERRORTYPE_INSERT_NO3
                                                     userInfo:@{NSLocalizedDescriptionKey:logKey}];
                        }
                        *rollback = YES; return NO;
                    }
                }
            }
            else if ([p.ocType isSubclassOfClass:p.associateClass]) // 直接嵌套
            {
                if (![value isKindOfClass:p.ocType])
                {
                    NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的%@嵌套属性类型为%@但KVC取值得到类型为%@", NSStringFromClass([self class]), p.name, NSStringFromClass(p.ocType), NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE
                                                     code:SY_ERRORTYPE_INSERT_NO2
                                                 userInfo:@{NSLocalizedDescriptionKey:logKey}];
                    }
                    *rollback = YES; return NO;
                }
                if (![value sy_InsertWithHeadNode:associatedColumnValue database:db rollback:rollback error:error]) {
                    return NO;
                }
            }
            else // 其他
            {
                NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的%@嵌套属性暂不支持数据库持久化", NSStringFromClass([self class]), p.name];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_NONSUPPORTTYPE
                                                 code:SY_ERRORTYPE_INSERT_NO4
                                             userInfo:@{NSLocalizedDescriptionKey:logKey}];
                }
                *rollback = YES; return NO;
            }
        }
    }
    else
    {
        NSString *logKey = [NSString stringWithFormat:@"(insert)%@类的非嵌套部分插入数据失败:(%@)", NSStringFromClass([self class]), sqlString];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE
                                         code:SY_ERRORTYPE_INSERT_NO5
                                     userInfo:@{NSLocalizedDescriptionKey:logKey}];
        }
        *rollback = YES; return NO;
    }
    
    return YES;
}

// FIXME: 更改
/// 改
- (BOOL)sy_UpdateWithError:(NSError *__autoreleasing*)error
{
    [self.class sy_ConfigProperties];
    
    if ([self sy_PrimaryKeyValue] <= 0) {
        NSString *logKey = [NSString stringWithFormat:@"(update)执行更新操作的模型不存在主键"];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE code:SY_ERRORTYPE_UPDATE_NO1 userInfo:@{NSLocalizedDescriptionKey: logKey}];
        }
        return NO;
    }
    
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self sy_UpdateWithDatabase:db rollback:rollback error:error];
    }];
    
    return result;
}

// UPDATE Person SET FirstName = 'Fred' WHERE LastName = 'Wilson'
+ (BOOL)sy_UpdateName:(NSString *)name newValue:(id)value condition:(NSString *)condition error:(NSError *__autoreleasing*)error
{
    [self.class sy_ConfigProperties];
    
    NSDictionary *unNestPart = objc_getAssociatedObject([self class], &SY_ASSOCIATED_SAVEPROPERTY);
    SY_Property *p = unNestPart[name];
    if (!p) return NO;
    
    NSMutableString *columnString = [NSMutableString string];
    NSMutableArray *valueList = [NSMutableArray array];
    
    // 基础数据类型且传入nil值
    if (p.unObjectCType == SYNotObjectCType_BaseData && (value == nil || [value isKindOfClass:[NSNull class]]))
    {
        [columnString appendFormat:@"%@=?", p.name];
        [valueList addObject:@0];
    }
    // 结构体且传入nil值
    else if (p.unObjectCType == SYNotObjectCType_Stuct && (value == nil || [value isKindOfClass:[NSNull class]]))
    {
        [columnString appendFormat:@"%@=?", p.name];
        if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
        {
            CGPoint point = CGPointZero;
            [valueList addObject:NSStringFromCGPoint(point)];
        }
        else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
        {
            CGSize size = CGSizeZero;
            [valueList addObject:NSStringFromCGSize(size)];
        }
        else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
        {
            CGRect rect = CGRectZero;
            [valueList addObject:NSStringFromCGRect(rect)];
        }
        else
        {
            
        }
    }
    // 空值
    else if (value == nil || [value isKindOfClass:[NSNull class]])
    {
        [columnString appendFormat:@"%@=null", p.name];
    }
    // 其他
    else
    {
        [columnString appendFormat:@"%@=?", p.name];
        if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSDictionary class]]) // 集合类
        {
            if (!([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]])) {
                NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与取出的值的类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO2 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                }
                return NO;
            }
            
            NSError *error = nil; NSData *data = nil;
            @try {
                // OC对象JSON序列化
                data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [valueList addObject:jsonStr];
                }else {
                    [valueList addObject:value];
                }
            }
            @catch (NSException *e) {
                [valueList addObject:value];
            }
        }
        else if ([p.ocType isSubclassOfClass:[NSDate class]]) // NSDate类型可保存为浮点型时间戳
        {
            if (![value isKindOfClass:[NSDate class]]) {
                NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与取出的值的类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO2 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                }
                return NO;
            }
            
            NSTimeInterval interval = [value timeIntervalSince1970];
            
            [valueList addObject:[NSNumber numberWithDouble:interval]];
        }
        else if (p.unObjectCType == SYNotObjectCType_Stuct && p.stuctName)
        {
            if (!([value isKindOfClass:[NSValue class]] && ![value isKindOfClass:[NSNumber class]])) {
                NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与取出的值的类型%@不一致", NSStringFromClass([self class]), p.name, p.stuctName, NSStringFromClass([value class])];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO2 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                }
                return NO;
            }
            
            if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
            {
                CGPoint point = CGPointZero;
                @try {
                    point = [value CGPointValue];  // CGPoint等结构体在使用KVC获取的时候自动打包成NSValue值, 需使用NSValue类对应实例方法取得原值
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGPoint(point)];
            }
            else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
            {
                CGSize size = CGSizeZero;
                @try {
                    size = [value CGSizeValue];
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGSize(size)];
            }
            else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
            {
                CGRect rect = CGRectZero;
                @try {
                    rect = [value CGRectValue];
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGRect(rect)];
            }
            else
            {
                return NO;
            }
        }
        else
        {
            if (![value isKindOfClass:p.ocType]) {
                NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与取出的值的类型%@不一致", NSStringFromClass(self), p.name, p.ocType, NSStringFromClass([value class])];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO2 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                }
                return NO;
            }
            [valueList addObject:value];
        }
    }
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", NSStringFromClass(self), columnString, condition];
    
    __block BOOL result = YES;
    
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [db executeUpdate:sql withArgumentsInArray:valueList];
        if (!result) {
            NSString *logKey = [NSString stringWithFormat:@"(update)类%@执行更新语句失败", NSStringFromClass([self class])];
            NSLog(@"[SY_Error]%@", logKey);
            if (error) {
                *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE code:SY_ERRORTYPE_UPDATE_NO3 userInfo:@{NSLocalizedDescriptionKey: logKey}];
            }
            *rollback = YES;
        }
    }];
    
    return result;
}

/// 将一个对象的内容赋给另一个同级对象 -- 将调用者的数据更新成参数传入的数据
/**
 *  调用者就是即将被更新到数据库中的数据
 *
 *  @return 是否更新成功
 */
- (BOOL)sy_UpdateWithDatabase:(FMDatabase *)db rollback:(BOOL *)rollback error:(NSError *__autoreleasing*)error
{
    // 非嵌套部分赋值
    if (![self sy_UpdateUnNestPartWithDatabase:db rollback:rollback error:error]) return NO;
    
    // 嵌套部分赋值
    if (![self sy_UpdateNestPartWithDatabase:db rollback:rollback error:error]) return NO;
    
    return YES;
}


/// 将一个对象的非嵌套部分更新
- (BOOL)sy_UpdateUnNestPartWithDatabase:(FMDatabase *)db rollback:(BOOL *)rollback error:(NSError *__autoreleasing*)error
{
    NSDictionary *unNestPart = objc_getAssociatedObject([self class], &SY_ASSOCIATED_SAVEPROPERTY);
    
    NSMutableArray *valueList = [NSMutableArray array];
    NSMutableString *columnString = [NSMutableString string];
    
    for (NSString *key in unNestPart.allKeys)
    {
        SY_Property *p = unNestPart[key];
        
        id value = nil;
        @try {
            value = [self valueForKey:p.name];
        }@catch (NSException *exc) {
            
        }
        
        if (value == nil || [value isKindOfClass:[NSNull class]]) {
            [columnString appendFormat:@"%@=null,", p.name];
            continue;
        }
        
        [columnString appendFormat:@"%@=?,", p.name];
        
        if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSDictionary class]]) // 集合类
        {
            NSError *error = nil; NSData *data = nil;
            @try {
                // OC对象JSON序列化
                data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [valueList addObject:jsonStr];
                }else {
                    [valueList addObject:value];
                }
            }
            @catch (NSException *e) {
                [valueList addObject:value];
            }
        }
        else if ([p.ocType isSubclassOfClass:[NSDate class]]) // NSDate类型可保存为浮点型时间戳
        {
            if (![value isKindOfClass:[NSDate class]]) {
                NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与KVC取出的值的类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                NSLog(@"[SY_Error]%@", logKey);
                if (error) {
                    *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO2 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                }
                *rollback = YES; return NO;
            }
            
            NSTimeInterval interval = [value timeIntervalSince1970];
            
            [valueList addObject:[NSNumber numberWithDouble:interval]];
        }
        else if (p.unObjectCType == SYNotObjectCType_Stuct && p.stuctName)
        {
            if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
            {
                CGPoint point = CGPointZero;
                @try {
                    point = [value CGPointValue];  // CGPoint等结构体在使用KVC获取的时候自动打包成NSValue值, 需使用NSValue类对应实例方法取得原值
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGPoint(point)];
            }
            else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
            {
                CGSize size = CGSizeZero;
                @try {
                    size = [value CGSizeValue];
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGSize(size)];
            }
            else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
            {
                CGRect rect = CGRectZero;
                @try {
                    rect = [value CGRectValue];
                }@catch (NSException *e) {
                    
                }
                
                [valueList addObject:NSStringFromCGRect(rect)];
            }
            else
            {
                [valueList addObject:value];
            }
        }
        else
        {
            [valueList addObject:value];
        }
    }
    
    if (columnString.length > 0) {
        [columnString deleteCharactersInRange:NSMakeRange(columnString.length - 1, 1)];
    }
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = %ld;", NSStringFromClass(self.class), columnString, SY_COLUMNNAME_KEYWORD, [self sy_PrimaryKeyValue]];
    
    BOOL isSuccess = [db executeUpdate:sql withArgumentsInArray:valueList];
    if (!isSuccess) {
        NSString *logKey = [NSString stringWithFormat:@"(update)类%@执行更新语句失败", NSStringFromClass([self class])];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE code:SY_ERRORTYPE_UPDATE_NO3 userInfo:@{NSLocalizedDescriptionKey: logKey}];
        }
        *rollback = YES; return NO;
    }
    
    return YES;
}

/// 将一个对象的嵌套部分赋值
- (BOOL)sy_UpdateNestPartWithDatabase:(FMDatabase *)db rollback:(BOOL *)rollback error:(NSError *__autoreleasing*)error
{
    NSDictionary *nestDic = objc_getAssociatedObject(self.class, &SY_ASSOCIATED_NESTPROPERTY);
    
    for (SY_Property *p in nestDic.allValues)
    {
        id value = nil;
        @try {
            value = [self valueForKey:p.name];
        }@catch (NSException *exc) {
            value = nil;
        }
        
        NSString *upNestString = [self sy_GetHeadNodeWithPropertyName:p.name];
        NSString *sqlString = [NSString stringWithFormat:@"where %@ = '%@'", SY_COLUMNNAME_HEADNODE, upNestString];
        NSArray *oldList = [p.associateClass sy_SearchByCondition:sqlString inDatabase:db error:nil];
        
        // 直接嵌套
        if ([p.ocType isEqual:p.associateClass])
        {
            if (oldList.count > 0 && value != nil)
            {
                if (![value isKindOfClass:p.associateClass]) {
                    NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与从KVC取值得到的值类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO4 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                    }
                    *rollback = YES; return NO;
                }
                
                // 假如数据库中该子嵌套存在, 则肯定可以得到其主键值
                long pk = [oldList.firstObject sy_PrimaryKeyValue];
                [value sy_SetPrimaryKeyValue:pk];
                
                if (![value sy_UpdateWithDatabase:db rollback:rollback error:error]) return NO;
            }
            // 数据库中存在数据且赋值数据为空(即把数据库中的数据删除)
            else if (oldList.count > 0 && value == nil)
            {
                if (![oldList.firstObject sy_RemoveNestWithError:error database:db rollback:rollback]) return NO;
            }
            // 数据库中不存在数据且赋值数据不为空(即新增赋值数据到数据库中)
            else if (oldList.count == 0 && value != nil)
            {
                if (![value isKindOfClass:p.associateClass]) {
                    NSString *logKey = [NSString stringWithFormat:@"(update)%@类的属性%@其类型%@与从KVC取值得到的值类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO4 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                    }
                    *rollback = YES; return NO;
                }
                
                NSString *tmpString = [self sy_GetHeadNodeWithPropertyName:p.name];
                if (![value sy_InsertWithHeadNode:tmpString database:db rollback:rollback error:error]) return NO;
            }
            // 数据库中不存在数据且赋值数据为空(不做操作)
            else
            {
                
            }
        }
        
        // 嵌套了数组
        else if ([p.ocType isSubclassOfClass:[NSArray class]])
        {
            // 1. 数据库中没有数据但赋值数据不为空(即直接把赋值数据保存到数据库中)
            if (oldList.count == 0 && value != nil)
            {
                if (![value isKindOfClass:[NSArray class]]) {
                    NSString *logKey = [NSString stringWithFormat:@"(update)%@类的嵌套属性%@其类型%@与从KVC取值得到的值类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO5 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                    }
                    *rollback = YES; return NO;
                }
                
                for (id tmpValue in value) {
                    if (![tmpValue sy_InsertWithHeadNode:upNestString database:db rollback:rollback error:error]) return NO;
                }
            }
            
            // 2. 数据库中存在数据但赋值数据为空(即把数据库中数据删除)
            else if (oldList.count > 0 && value == nil)
            {
                if (![oldList sy_RemoveArrayWithError:error database:db rollback:rollback]) return NO;
            }
            
            // 3. 数据库中存在数据且赋值数据也不为空(依次把赋值数据更新到数据库中，不足部分移除数据库中原有数据, 超出部分依次添加到数据库中)
            else if (oldList.count > 0 && value != nil)
            {
                if (![value isKindOfClass:[NSArray class]]) {
                    NSString *logKey = [NSString stringWithFormat:@"(update)%@类的嵌套属性%@其类型%@与从KVC取值得到的值类型%@不一致", NSStringFromClass([self class]), p.name, p.ocType, NSStringFromClass([value class])];
                    NSLog(@"[SY_Error]%@", logKey);
                    if (error) {
                        *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO5 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                    }
                    *rollback = YES; return NO;
                }
                
                long tmpCount = [value count];
                if (oldList.count > tmpCount)
                {
                    for (int i = 0; i < oldList.count; i++) {
                        
                        if (![value[i] isKindOfClass:p.associateClass]) {
                            NSString *logKey = [NSString stringWithFormat:@"(update)%@类的嵌套属性%@其声明的嵌套类型%@与从KVC取值得到的其子值类型%@不一致", NSStringFromClass([self class]), p.name, p.associateClass, NSStringFromClass([value[i] class])];
                            NSLog(@"[SY_Error]%@", logKey);
                            if (error) {
                                *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO6 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                            }
                            *rollback = YES; return NO;
                        }
                        
                        // 数据库中对应索引数据更新为该赋值数据
                        if (i < tmpCount) {
                            long pk = [oldList[i] sy_PrimaryKeyValue];
                            [value[i] sy_SetPrimaryKeyValue:pk];
                            if (![value[i] sy_UpdateWithDatabase:db rollback:rollback error:error]) return NO;
                        }
                        // 超出部分移除
                        else {
                            if (![oldList[i] sy_RemoveNestWithError:error database:db rollback:rollback]) return NO;
                        }
                    }
                }
                
                // 数据库中数据比赋值的数据少
                else
                {
                    for (int i = 0; i < tmpCount; i++) {
                        
                        if (![value[i] isKindOfClass:p.associateClass]) {
                            NSString *logKey = [NSString stringWithFormat:@"(update)%@类的嵌套属性%@其声明的嵌套类型%@与从KVC取值得到的其子值类型%@不一致", NSStringFromClass([self class]), p.name, p.associateClass, NSStringFromClass([value[i] class])];
                            NSLog(@"[SY_Error]%@", logKey);
                            if (error) {
                                *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_UPDATE_NO6 userInfo:@{NSLocalizedDescriptionKey: logKey}];
                            }
                            *rollback = YES; return NO;
                        }
                        
                        // 数据库中对应索引数据更新为该赋值数据
                        if (i < oldList.count) {
                            long pk = [oldList[i] sy_PrimaryKeyValue];
                            [value[i] sy_SetPrimaryKeyValue:pk];
                            if (![value[i] sy_UpdateWithDatabase:db rollback:rollback error:error]) return NO;
                        }
                        // 超出部分新增
                        else {
                            if (![value[i] sy_InsertWithHeadNode:upNestString database:db rollback:rollback error:error]) return NO;
                        }
                    }
                }
            }
            
            // 4. 数据库与赋值数据皆不存在(不做操作)
            else
            {
                
            }
        }
        
        // 嵌套字典等其他嵌套模式暂时不支持
        else
        {
            
        }
    }
    
    return YES;
}

/// 只能是嵌套上级调用并传入其相关属性名来组合成头链的值
- (NSString *)sy_GetHeadNodeWithPropertyName:(NSString *)name
{
    long pk = [self sy_PrimaryKeyValue];
    NSString *tmp = [NSString stringWithFormat:@"%@%@%@%@%ld", NSStringFromClass(self.class), SY_SING_HEADNODE, name, SY_SING_HEADNODE, pk];
    return tmp;
}

// FIXME: 查询

/// 查询表中所有数据
+ (NSArray *)sy_FindAllWithError:(NSError **)error
{
    return [self sy_FindByCondition:nil error:error];
}

/// 查
+ (NSArray *)sy_FindByCondition:(NSString *)condition error:(NSError * __autoreleasing *)error
{
    [self.class sy_ConfigProperties];
    
    if (condition == nil) condition = @"";
    
    __block NSArray *array = nil;
    [[SY_FMDBManager manager].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        array = [self sy_SearchByCondition:condition inDatabase:db error:error];
    }];
    
    return array;
}

+ (NSArray *)sy_FindName:(NSString *)name condition:(NSString *)condition error:(NSError * __autoreleasing *)error;
{
    [self sy_ConfigProperties];
    
    __block NSArray *array = nil;
    if (!name || [name isKindOfClass:[NSNull class]]) {
        [[SY_FMDBManager manager].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
            array = [self sy_SearchByCondition:condition inDatabase:db error:error];
        }];
    }else {
        condition = (condition && ![condition isKindOfClass:[NSNull class]]) ? condition : @"";
        [[SY_FMDBManager manager].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
            array = [self sy_selectName:name condition:condition inDatabase:db error:error];
        }];
    }
    
    return array;
}

+ (NSArray *)sy_selectName:(NSString *)name condition:(NSString *)condition inDatabase:(FMDatabase *)db error:(NSError **)error
{
    NSString *sql = [NSString stringWithFormat:@"select %@ from %@ %@", name, NSStringFromClass(self), condition];
    FMResultSet *resultSet = [db executeQuery:sql];
    
    // 1. 表示查询出错
    if (resultSet == nil)
    {
        NSString *logKey = [NSString stringWithFormat:@"(select)查询语句发生错误:(%@)", sql];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE
                                         code:SY_ERRORTYPE_SELECT_NO1
                                     userInfo:@{NSLocalizedDescriptionKey:logKey}];
        }
        return nil;
    }
    
    NSDictionary *storeDic = objc_getAssociatedObject(self, &SY_ASSOCIATED_SAVEPROPERTY);
    SY_Property *p = storeDic[name];
    if (p == nil) return nil;
    
    // 2.1 初始化一个可变数组保存转变完的模型
    NSMutableArray *resultList = [NSMutableArray array];
    
    // 3. 遍历结果集(结果集中是一条条数据[数据中不包含嵌套的属性])
    while ([resultSet next]) // 当结果集中仍然有下一条数据时进入循环
    {
        NSDictionary *dic = [resultSet resultDictionary];
        id value = dic[name];
        
        if (p.ocType != nil && ![p.ocType isSubclassOfClass:[NSNull class]]) // OC对象
        {
            if (value == nil || [value isKindOfClass:[NSNull class]]) continue;
            if ([p.ocType isSubclassOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) // 字符串类型
            {
                [resultList addObject:value];
            }
            else if ([p.ocType isSubclassOfClass:[NSNumber class]] && [value isKindOfClass:[NSNumber class]]) // NSNumber类型
            {
                [resultList addObject:value];
            }
            else if ([p.ocType isSubclassOfClass:[NSArray class]]) // 数组或字典
            {
                NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error = nil;
                id objc = [NSJSONSerialization JSONObjectWithData:valueData options:kNilOptions error:&error];
                if (error) {
                    NSLog(@"反序列化失败");
                    continue;
                }
                [resultList addObject:objc];
            }
            else if ([p.ocType isSubclassOfClass:[NSDate class]]) // NSDate类型
            {
                NSNumber *number = [dic valueForKey:p.name];
                // 根据时间戳获取NSDate对象
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:number.doubleValue];
                [resultList addObject:date];
            }
            else // 其他
            {
                [resultList addObject:value];
            }
        }
        else if (p.unObjectCType == SYNotObjectCType_Stuct && p.stuctName) // 结构体
        {
            if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
            {
                CGPoint point = CGPointFromString(value);
                NSValue *nsValue = [NSValue valueWithCGPoint:point];
                [resultList addObject:nsValue];
            }
            else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
            {
                CGSize size = CGSizeFromString(value);
                NSValue *nsValue = [NSValue valueWithCGSize:size];
                [resultList addObject:nsValue];
            }
            else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
            {
                CGRect rect = CGRectFromString(value);
                NSValue *nsValue = [NSValue valueWithCGRect:rect];
                [resultList addObject:nsValue];
            }
            else
            {
                // 默认为空
            }
        }
        else // 其他
        {
            [resultList addObject:value];
        }
    }
    
    return resultList;
}

/**
 *  不暴露方法: 根据传入的sql语句从数据库中查询相应数据并在得到数据后转化为模型时做初始化用
 *
 *  @param condition 查询的条件
 *
 *  @return 查询到的结果且结果可以为空但不为nil
 */
+ (NSArray *)sy_SearchByCondition:(NSString *)condition inDatabase:(FMDatabase *)db error:(NSError **)error
{
    NSString *sql = [NSString stringWithFormat:@"select * from %@ %@;", NSStringFromClass(self), condition];
    
    FMResultSet *resultSet = [db executeQuery:sql];
    
    // 1. 表示查询出错
    if (resultSet == nil)
    {
        NSString *logKey = [NSString stringWithFormat:@"(select)查询语句发生错误:(%@)", sql];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE
                                         code:SY_ERRORTYPE_SELECT_NO1
                                     userInfo:@{NSLocalizedDescriptionKey:logKey}];
        }
        return nil;
    }
    
    
    // 2. 被保存属性列表与嵌套属性列表
    NSDictionary *storeDic = objc_getAssociatedObject(self, &SY_ASSOCIATED_SAVEPROPERTY);
    NSDictionary *nestDic = objc_getAssociatedObject(self, &SY_ASSOCIATED_NESTPROPERTY);
    
    // 2.1 初始化一个可变数组保存转变完的模型
    NSMutableArray *resultModels = [NSMutableArray array];
    
    // 3. 遍历结果集(结果集中是一条条数据[数据中不包含嵌套的属性])
    while ([resultSet next]) // 当结果集中仍然有下一条数据时进入循环
    {
        NSDictionary *dic = [resultSet resultDictionary];
        
        id model = [[self alloc] init];
        
        long pk = [[dic valueForKey:SY_COLUMNNAME_KEYWORD] longValue];
        [model sy_SetPrimaryKeyValue:pk];
        NSString *superiorKey = [dic valueForKey:SY_COLUMNNAME_HEADNODE];
        [model sy_SetSuperiorKeyValue:superiorKey];
        
        for (NSString *key in storeDic.allKeys)
        {
            SY_Property *p = storeDic[key];
            
            // 分为[1. OC对象(字符串、数组、字典、NSNumber、Class)、2. 非OC对象(基础数据类型、Block、结构体)]
            if (p.ocType != nil && ![p.ocType isSubclassOfClass:[NSNull class]]) // OC对象
            {
                NSString *value = [dic valueForKey:p.name];
                if (value == nil || [value isKindOfClass:[NSNull class]]) continue;
                if ([p.ocType isSubclassOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) // 字符串类型
                {
                    [model setValue:(p.isMutable ? value.mutableCopy : value) forKey:p.name];
                }
                else if ([p.ocType isSubclassOfClass:[NSNumber class]] && [value isKindOfClass:[NSNumber class]]) // NSNumber类型
                {
                    [model setValue:value forKey:p.name];
                }
                else if ([p.ocType isSubclassOfClass:[NSArray class]]) // 数组或字典
                {
                    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *error = nil;
                    id objc = [NSJSONSerialization JSONObjectWithData:valueData options:kNilOptions error:&error];
                    if (error) {
                        NSLog(@"反序列化失败");
                        continue;
                    }
                    [model setValue:objc forKey:p.name];
                }
                else if ([p.ocType isSubclassOfClass:[NSDate class]]) // NSDate类型可保存为浮点型时间戳
                {
                    NSNumber *number = [dic valueForKey:p.name];
                    // 根据时间戳获取NSDate对象
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:number.doubleValue];
                    [model setValue:date forKey:p.name];
                }
                else // 其他
                {
                    [model setValue:[dic valueForKey:p.name] forKey:p.name];
                }
            }
            else if (p.unObjectCType == SYNotObjectCType_Stuct && p.stuctName)
            {
                // 结构体转化的字符串
                NSString *value = [dic valueForKey:p.name];
                
                if ([p.stuctName isEqualToString:@"CGPoint"]) // CGPoint
                {
                    [model setValue:[NSValue valueWithCGPoint:CGPointFromString(value)] forKey:p.name];
                }
                else if ([p.stuctName isEqualToString:@"CGSize"]) // CGSize
                {
                    [model setValue:[NSValue valueWithCGSize:CGSizeFromString(value)] forKey:p.name];
                }
                else if ([p.stuctName isEqualToString:@"CGRect"]) // CGRect
                {
                    [model setValue:[NSValue valueWithCGRect:CGRectFromString(value)] forKey:p.name];
                }
                else
                {
                    // 默认为空
                }
            }
            else // 其他
            {
                [model setValue:[dic valueForKey:p.name] forKey:p.name];
            }
        }
        
        for (NSString *key in nestDic.allKeys)
        {
            SY_Property *p = nestDic[key];
            
            NSString *tableName = NSStringFromClass(self);
            NSString *propertyName = p.name;
            long dataID = [model sy_PrimaryKeyValue];
            
            NSString *sql = [NSString stringWithFormat:@"where %@ = '%@'", SY_COLUMNNAME_HEADNODE, [NSString stringWithFormat:@"%@%@%@%@%ld", tableName, SY_SING_HEADNODE, propertyName, SY_SING_HEADNODE, dataID]];
            
            NSArray *resultModelArray = [p.associateClass sy_SearchByCondition:sql inDatabase:db error:error];
            
            if (resultModelArray == nil || [resultModelArray isKindOfClass:[NSNull class]]) continue;
            
            if ([p.ocType isSubclassOfClass:[NSArray class]]) // 数组
            {
                if (resultModelArray.count > 0) {
                    [model setValue:(p.isMutable ? resultModelArray.mutableCopy : resultModelArray) forKey:p.name];
                }
            }
            else if ([p.ocType isSubclassOfClass:p.associateClass]) // 直接嵌套
            {
                // 取出数组中第一个值赋给作为嵌套类的属性
                if (resultModelArray.count > 0) {
                    [model setValue:resultModelArray.firstObject forKey:p.name];
                }
            }
            else // 其他嵌套类型暂不支持
            {
//                if (error) {
//                    *error = [NSError errorWithDomain:@"②"
//                                                 code:1
//                                             userInfo:@{NSLocalizedDescriptionKey:@"嵌套类型为字典, 该功能暂不支持"}];
//                }
            }
        }
        
        [resultModels addObject:model];
        FMDBRelease(model);
    }
    
    
    return resultModels;
}

// FIXME: 删除
+ (BOOL)sy_RemoveByCondition:(NSString *)condition andError:(NSError *__autoreleasing*)error
{
    [self.class sy_ConfigProperties];
    
    __block BOOL result = YES;
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        NSArray *array = [self sy_SearchByCondition:condition inDatabase:db error:error];
        
        for (id subValue in array) {
            if (![subValue sy_RemoveNestWithError:error database:db rollback:rollback])
            {
                result = NO;
                break;
            }
        }
    }];
    
    return result;
}

- (BOOL)sy_RemoveWithError:(NSError *__autoreleasing*)error
{
    [self.class sy_ConfigProperties];
    
    // 1. 判断数据库中是否存在该条数据
    if ([self sy_PrimaryKeyValue] <= 0) {
        NSString *logKey = [NSString stringWithFormat:@"(delete)%@类的实例对象不存在主键值", NSStringFromClass([self class])];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_DELETE_NO1 userInfo:@{NSLocalizedDescriptionKey: logKey}];
        }
        return NO;
    }
    
    __block BOOL result = YES;
    // 2. 数据库队列调起事务来处理删除操作
    [[SY_FMDBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self sy_RemoveNestWithError:error database:db rollback:rollback];
    }];
    
    return result;
}

- (BOOL)sy_RemoveNestWithError:(NSError **)error database:(FMDatabase *)db rollback:(BOOL * _Nonnull)rollback
{
    if ([self sy_PrimaryKeyValue] <= 0)
    {
        NSString *logKey = [NSString stringWithFormat:@"(delete)%@类的实例对象不存在主键值", NSStringFromClass([self class])];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_DELETE_NO1 userInfo:@{NSLocalizedDescriptionKey: logKey}];
        }
        *rollback = YES;
        return NO;
    }
    
    NSDictionary *nestDic = objc_getAssociatedObject([self class], &SY_ASSOCIATED_NESTPROPERTY);
    
    for (NSString *key in nestDic.allKeys) // 移除嵌套属性
    {
        SY_Property *p = nestDic[key];
        
        // 组合嵌套类的头结点
        NSString *headNode = [self sy_GetHeadNodeWithPropertyName:p.name];
        
        // 数据库中查找
        NSArray *results = [p.associateClass sy_SearchByCondition:[NSString stringWithFormat:@"where %@ = '%@'", SY_COLUMNNAME_HEADNODE, headNode] inDatabase:db error:error];
        
        if (results == nil) {*rollback = YES; return NO;}
        
        if (results.count == 0) continue;
        
        if ([p.associateClass isSubclassOfClass:p.ocType]) // 直接嵌套
        {
            id value = results.firstObject;
            
            if (![value sy_RemoveNestWithError:error database:db rollback:rollback]) return NO;
        }
        else if ([p.ocType isSubclassOfClass:[NSArray class]]) // 数组嵌套
        {
            if (![results sy_RemoveArrayWithError:error database:db rollback:rollback]) return NO;
        }
        else
        {
            
        }
    }
    
    // 非嵌套部分
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = %ld;", NSStringFromClass(self.class), SY_COLUMNNAME_KEYWORD, [self sy_PrimaryKeyValue]];
    BOOL isSuccess = [db executeUpdate:sql];
    if (isSuccess == NO) {
        NSString *logKey = [NSString stringWithFormat:@"(delete)%@类的实例对象执行删除语句失败", NSStringFromClass([self class])];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_FAILEDEXECUTE code:SY_ERRORTYPE_DELETE_NO2 userInfo:@{NSLocalizedDescriptionKey:logKey}];
        }
        *rollback = YES; return NO;
    }
    
    return YES;
}

/// 调用者是从数据库中经过搜索得到的结果集
- (BOOL)sy_RemoveArrayWithError:(NSError **)error database:(FMDatabase *)db rollback:(BOOL * _Nonnull)rollback
{
    if (![self isKindOfClass:[NSArray class]]) {
        NSString *logKey = [NSString stringWithFormat:@"(delete)调用者类型不是数组:%@", NSStringFromClass([self class])];
        NSLog(@"[SY_Error]%@", logKey);
        if (error) {
            *error = [NSError errorWithDomain:SY_DOMAIN_WRONGTYPE code:SY_ERRORTYPE_DELETE_NO3 userInfo:@{NSLocalizedDescriptionKey:logKey}];
        }
        *rollback = YES; return NO;
    }
    
    for (id value in (NSArray *)self) {
        if (![value sy_RemoveNestWithError:error database:db rollback:rollback]) return NO;
    }
    
    return YES;
}

#pragma mark- <-----------  关联属性  ----------->
- (void)sy_SetPrimaryKeyValue:(long)pk
{
    objc_setAssociatedObject(self, &SY_ASSOCIATED_PRIMARYKEY, [NSNumber numberWithInteger:pk], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (long)sy_PrimaryKeyValue
{
    return [objc_getAssociatedObject(self, &SY_ASSOCIATED_PRIMARYKEY) longValue];
}

- (void)sy_SetSuperiorKeyValue:(NSString *)newValue
{
    objc_setAssociatedObject(self, &SY_COLUMNNAME_HEADNODE, newValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)sy_SuperiorKeyValue
{
    return objc_getAssociatedObject(self, &SY_COLUMNNAME_HEADNODE);
}

@end
