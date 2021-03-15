//
//  SYPropertyInfo.h
//
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//  类的变量的信息

#import <Foundation/Foundation.h>


/// 基础数据的类型
typedef NS_ENUM(NSUInteger, SY_BASEDATA_TYPE)
{
    // 其他类型
    SY_BASEDATA_TYPE_UNKNOWN,
    // int64位类型、long类型、longlong类型
    SY_BASEDATA_TYPE_INT64,
    // int32位类型、int类型
    SY_BASEDATA_TYPE_INT32,
    // int16位类型
    SY_BASEDATA_TYPE_INT16,
    // int8位类型
    SY_BASEDATA_TYPE_INT8,
    // 单精度float类型
    SY_BASEDATA_TYPE_FLOAT,
    // 双精度double类型、双精度CGFloat
    SY_BASEDATA_TYPE_DOUBLE,
    // BOOL类型
    SY_BASEDATA_TYPE_BOOL,
};

///// 已授权可以存储的结构体类型
//typedef NS_ENUM(NSUInteger, SY_AUTHORIZED_STUCT_TYPE)
//{
//    // 1.CGRect
//    SY_AUTHORIZED_STUCT_TYPE_CGRECT,
//    // 2.CGPoint
//    SY_AUTHORIZED_STUCT_TYPE_CGPOINT,
//    // 3.CGSize
//    SY_AUTHORIZED_STUCT_TYPE_CGSIZE,
//};



/// 数据库存储的类型
typedef NS_ENUM(NSUInteger, SY_SQLITE_CACHE_TYPE)
{
    // 1.INTEGER整型
    SY_SQLITE_CACHE_TYPE_INTEGER,
    // 2.TEXT字符串型
    SY_SQLITE_CACHE_TYPE_TEXT,
    // 3.REAL浮点型
    SY_SQLITE_CACHE_TYPE_REAL,
    // 4.BLOB二进制型
    SY_SQLITE_CACHE_TYPE_BLOB,
    // 5.NULL空型
    SY_SQLITE_CACHE_TYPE_NULL,
};

/// 属性类型: 1.OC对象、2.基础数据类型、3.Block、4.结构体
typedef NS_ENUM(NSUInteger, SY_Variable_TYPE)
{
    // 0.未知
    SY_Variable_TYPE_UNKNOW,
    /// 1.OC对象
    SY_Variable_TYPE_OBJECTC,
    /// 2.基础数据类型
    SY_Variable_TYPE_BASEDATA,
    /// 3.Block
    SY_Variable_TYPE_BLOCK,
    /// 4.结构体
    SY_Variable_TYPE_STUCT,
    /// 5.id类型
    SY_Variable_TYPE_ID,
};

//typedef NS_ENUM(NSUInteger, SYNotObjectCType) {
//    /// 1. block类型
//    SYNotObjectCType_Block            = 1,
//    /// 2. 结构体类型
//    SYNotObjectCType_Stuct            = 2,
//    /// 3. id类型(未遵循任何协议)
//    SYNotObjectCType_Id               = 3,
//    /// 4. id类型(遵循了某些协议)
//    SYNotObjectCType_IdOfProtocol     = 4,
//    /// 5. 基础数据类型
//    SYNotObjectCType_BaseData         = 5,
//};

@interface SYPropertyInfo : NSObject

/// 该属性名称(区分大小写)
@property (nonatomic, copy) NSString *name;

/// 该属性是否只读
@property (nonatomic, assign, getter=isReadOnly) BOOL readOnly;

/// 是否可变属性(如果可变,从数据库提取的值应该置为可变状态)
@property (nonatomic, assign) BOOL isMutable;

/// 该属性OC类型 -- [有值:1. NSObject对象类型]、[无值:1.Block类型、2.结构体类型、3.基础数据类型]
@property (nonatomic, assign) Class ocType;

/// 变量类型(0.未知、1.OC、2.基础数据、3.Block、4.Stuct、5.id)
@property (nonatomic, assign) SY_Variable_TYPE variableType;

/// 变量的属性信息
@property (nonatomic, copy) NSString *attributes;

/// 该属性遵循的协议名数组(可能一个属性遵循了多个协议)
@property (nonatomic, strong) NSMutableArray *protocolList;

/// 该属性如果为结构体则结构体类型(1.CGPoint、2.CGSize、3.CGRect)
@property (nonatomic, copy) NSString *stuctName;

/// 基础数据类型(在OC中的类型转字符串)
@property (nonatomic, assign) SY_BASEDATA_TYPE basedataType;

#pragma mark- 数据库扩展
/// 该属性如果为嵌套, 则该值不为nil(直接嵌套, 或者通过集合的方式嵌套)
@property (nonatomic, assign) Class associateClass;

/// 该变量是否需要保存
@property (nonatomic, assign) BOOL cacheEnable;

/// 保存到SQL中的类型 -- 1.INTEGER整型  2.TEXT字符串型  3.REAL浮点型  4.BLOB二进制型  5.NULL空型
@property (nonatomic, assign) SY_SQLITE_CACHE_TYPE sqliteCacheType;

/// 在SQL中的存储类型(1.BLOB、2.NULL、3.REAL、4.TEXT、5.INTEGER)
@property (nonatomic, copy) NSString *cacheTypeInSQL;

//+ (instancetype)infoWithInfo:(SYPropertyInfo *)info;

@end
