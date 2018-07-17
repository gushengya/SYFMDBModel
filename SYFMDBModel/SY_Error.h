//
//  SY_Error.h
//  Demo
//
//  Created by 谷胜亚 on 2018/7/16.
//  Copyright © 2018年 gushengya. All rights reserved.
//

/// 错误域名
static NSString *const SY_DOMAIN_WRONGTYPE = @"SY_DOMAIN_WRONGTYPE"; // 类型不一致
static NSString *const SY_DOMAIN_NONSUPPORTTYPE = @"SY_DOMAIN_NONSUPPORTTYPE"; // 不支持的类型
static NSString *const SY_DOMAIN_FAILEDEXECUTE = @"SY_DOMAIN_FAILEDEXECUTE"; // 执行的SQL语句失败


/// 错误具体类型
typedef NS_ENUM(NSInteger, SY_ERRORTYPE) {
    /// 非嵌套部分有属性其声明的类型与由KVC取得的值的类型不一致
    SY_ERRORTYPE_INSERT_NO1 = -1001,
    /// 嵌套部分有属性其声明的类型与由KVC取得的值的类型不一致
    SY_ERRORTYPE_INSERT_NO2 = -1002,
    /// 嵌套部分有属性类型为集合时其子值类型与嵌套声明的类型不一致
    SY_ERRORTYPE_INSERT_NO3 = -1003,
    /// 嵌套部分有属性类型暂时不支持插入到数据库
    SY_ERRORTYPE_INSERT_NO4 = -1004,
    /// 非嵌套部分执行SQL语句失败
    SY_ERRORTYPE_INSERT_NO5 = -1005,
    
    /// 查询执行SQL语句失败
    SY_ERRORTYPE_SELECT_NO1 = -2001,
    
    /// 即将删除的对象不存在主键因此断定不是从数据库中取出的值
    SY_ERRORTYPE_DELETE_NO1 = -3001,
    /// 非嵌套部分执行SQL语句删除失败
    SY_ERRORTYPE_DELETE_NO2 = -3002,
    /// 调用者非数组删除多个数据出错
    SY_ERRORTYPE_DELETE_NO3 = -3003,
    
    /// 即将更新的对象不存在主键因此断定不是从数据库中取出的值
    SY_ERRORTYPE_UPDATE_NO1 = -4001,
    /// 非嵌套部分有属性类型为NSDate但由KVC取得的值不是NSDate类型
    SY_ERRORTYPE_UPDATE_NO2 = -4002,
    /// 非嵌套部分执行SQL语句更新失败
    SY_ERRORTYPE_UPDATE_NO3 = -4003,
    /// 嵌套部分有属性其类型与由KVC取值类型不一致
    SY_ERRORTYPE_UPDATE_NO4 = -4004,
    /// 嵌套部分有属性类型为数组但KVC取值类型与其不一致
    SY_ERRORTYPE_UPDATE_NO5 = -4005,
    /// 嵌套部分有属性类型是数组但其子值类型与嵌套声明类型不一致
    SY_ERRORTYPE_UPDATE_NO6 = -4006,
};
