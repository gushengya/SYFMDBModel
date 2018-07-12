//
//  SY_Property.h
//
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 属性类型: 1.OC对象、2.基础数据类型、3.Block、4.结构体
typedef NS_ENUM(NSUInteger, STORE_PROPERTY_TYPE) {
    /// 1.OC对象
    STORE_PROPERTY_TYPE_OBJECT,
    /// 2.基础数据类型
    STORE_PROPERTY_TYPE_BASEDATA,
    /// 3.Block
    STORE_PROPERTY_TYPE_BLOCK,
    /// 4.结构体
    STORE_PROPERTY_TYPE_STUCT,
    /// 5.id类型
    STORE_PROPERTY_TYPE_ID,
};

typedef NS_ENUM(NSUInteger, SYNotObjectCType) {
    /// 1. block类型
    SYNotObjectCType_Block            = 1,
    /// 2. 结构体类型
    SYNotObjectCType_Stuct            = 2,
    /// 3. id类型(未遵循任何协议)
    SYNotObjectCType_Id               = 3,
    /// 4. id类型(遵循了某些协议)
    SYNotObjectCType_IdOfProtocol     = 4,
    /// 5. 基础数据类型
    SYNotObjectCType_BaseData         = 5,
};

@interface SY_Property : NSObject

/// 属性名称
@property (nonatomic, copy) NSString *name;

/// 是否只读
@property (nonatomic, assign) BOOL isReadOnly;

/// 指定需要保存的属性
@property (nonatomic, assign) BOOL isSave;

/// 是否可变属性(如果可变,从数据库提取的值应该置为可变状态)
@property (nonatomic, assign) BOOL isMutable;

/// OC类型 -- [有值:1. NSObject对象类型]、[无值:1.Block类型、2.结构体类型、3.基础数据类型]
@property (nonatomic, assign) Class ocType;

/// 保存到SQL中的类型 -- 1.INTEGER整型  2.TEXT字符串型  3.REAL浮点型  4.BLOB二进制型  5.NULL空型
@property (nonatomic, copy) NSString *sqlTypeName;

/// 属性遵守的协议名数组
@property (nonatomic, strong) NSMutableArray *protocolNameList;

/// 属性所包含的类遵守了DBModelProtocol协议
@property (nonatomic, assign) Class associateClass;

/// 非OC类型(使用enum区分)
@property (nonatomic, assign) SYNotObjectCType unObjectCType;

/// 基础数据类型(在OC中的类型转字符串)
@property (nonatomic, copy) NSString *baseDataName;

/// 是否被标记为不支持存储类型(也就是被忽略)
@property (nonatomic, assign) BOOL isIgnore;

/// 已授权解析的结构体类型(1.CGPoint、2.CGSize、3.CGRect)
@property (nonatomic, copy) NSString *stuctName;

@end
