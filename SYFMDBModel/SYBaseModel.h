//
//  SYBaseModel.h
//  Demo
//
//  Created by 谷胜亚 on 2021/1/27.
//  Copyright © 2021 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SYDefineFile.h"
NS_ASSUME_NONNULL_BEGIN

@interface SYBaseModel : NSObject<SYClassCache, NSCopying>

/// !!!:插入数据
- (BOOL)__SY_Insert;

/// !!!:删除数据 
- (BOOL)__SY_Delete;

/// 删除数据(类方法可外露) DELETE FROM STUDENT WHERE age < 25;
+ (BOOL)__SY_DeleteWithCondition:(NSString * __nullable)condition;

/// !!!:更改
- (BOOL)__SY_Update;

/// !!!:查询  SELECT * FROM table_name;
+ (NSArray *)__SY_SelectAll;

/// 根据条件查询语句 SELECT * FROM table_name WHERE A = a;
+ (NSArray *)__SY_SelectWithCondition:(NSString * __nullable)condition;
@end

NS_ASSUME_NONNULL_END
