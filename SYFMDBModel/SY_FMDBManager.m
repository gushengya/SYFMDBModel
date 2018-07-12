//
//  SY_FMDBManager.m
//
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "SY_FMDBManager.h"

@interface SY_FMDBManager()

/// 数据库队列
@property (nonatomic, strong) FMDatabaseQueue *databaseQueue;

/// 数据库文件完整路径
@property (nonatomic, copy) NSString *dbFilePath;

@end

@implementation SY_FMDBManager

+ (instancetype)manager
{
    static SY_FMDBManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[SY_FMDBManager alloc] init];
    });
    
    return _instance;
}

- (FMDatabaseQueue *)databaseQueue
{
    if (!_databaseQueue) {
        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbFilePath];
    }
    
    return _databaseQueue;
}

- (NSString *)dbFilePath
{
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *filemanage = [NSFileManager defaultManager];
    
    if (self.dbFileDirectoryName == nil || self.dbFileDirectoryName.length == 0) {
        docsdir = [docsdir stringByAppendingPathComponent:@"SYFMDBModel"];
    } else {
        docsdir = [docsdir stringByAppendingPathComponent:self.dbFileDirectoryName];
    }
    BOOL isDir;
    
    BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
    
    if (!exit || !isDir) {
        
        
        [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // 拼接数据库的文件名到该目录上形成数据库文件的完整路径
    NSString *dbpath = [docsdir stringByAppendingPathComponent:@"duia.sqlite"];
    NSLog(@"数据库文件路径:[%@]", dbpath);
    return dbpath;
}

@end
