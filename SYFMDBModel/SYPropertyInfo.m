//
//  SYPropertyInfo.m
//
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "SYPropertyInfo.h"

@implementation SYPropertyInfo

//+ (instancetype)infoWithInfo:(SYPropertyInfo *)info
//{
//    SYPropertyInfo *tmp = [[SYPropertyInfo alloc] init];
//    /// 该属性名称(区分大小写)
//    tmp.name = info.name;
//
//    /// 该属性是否只读
//    tmp.readOnly = info.readOnly;
//
//    /// 是否可变属性(如果可变,从数据库提取的值应该置为可变状态)
//    tmp.isMutable = info.isMutable;
//
//    /// 该属性OC类型 -- [有值:1. NSObject对象类型]、[无值:1.Block类型、2.结构体类型、3.基础数据类型]
//    tmp.ocType = info.ocType;
//
//    /// 变量类型(0.未知、1.OC、2.基础数据、3.Block、4.Stuct、5.id)
//    tmp.variableType = info.variableType;
//
//    /// 变量的属性信息
//    tmp.attributes = info.attributes;
//
//    /// 该属性遵循的协议名数组(可能一个属性遵循了多个协议)
//    tmp.protocolList = info.protocolList;
//
//    /// 该属性如果为结构体则结构体类型(1.CGPoint、2.CGSize、3.CGRect)
//    tmp.stuctName = info.stuctName;
//
//    /// 基础数据类型(在OC中的类型转字符串)
//    tmp.basedataType = info.basedataType;
//
//    #pragma mark- 数据库扩展
//    /// 该属性如果为嵌套, 则该值不为nil(直接嵌套, 或者通过集合的方式嵌套)
//    tmp.associateClass = info.associateClass;
//
//    /// 该变量是否需要保存
//    tmp.cacheEnable = info.cacheEnable;
//
//    /// 保存到SQL中的类型 -- 1.INTEGER整型  2.TEXT字符串型  3.REAL浮点型  4.BLOB二进制型  5.NULL空型
//    tmp.sqliteCacheType = info.sqliteCacheType;
//
//    /// 在SQL中的存储类型(1.BLOB、2.NULL、3.REAL、4.TEXT、5.INTEGER)
//    tmp.cacheTypeInSQL = info.cacheTypeInSQL;
//    
//    return tmp;
//}

@end
