//
//  SY_FMDBManager.h
//  
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//  方便数据库信息管理

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>

@interface SY_FMDBManager : NSObject

/// 数据库队列
@property (nonatomic, strong, readonly) FMDatabaseQueue *databaseQueue;

/// 数据库文件目录名称 -- 如不设置使用默认文件夹名
@property (nonatomic, copy) NSString *dbFileDirectoryName;

/// 数据库文件完整路径
@property (nonatomic, copy, readonly) NSString *dbFilePath;

/// 单例实例化
+ (instancetype)manager;

@end
