//
//  SYDefineFile.h
//  Demo
//
//  Created by 谷胜亚 on 2021/2/2.
//  Copyright © 2021 gushengya. All rights reserved.
//

@protocol SYClassCache
+ (BOOL)__SY_CacheEnableOfPropertyName:(SEL)selector;
/// 嵌套属性映射(如有嵌套属性, 需重写该方法返回key为字段名、value为Class)
+ (NSDictionary *)__SY_NestClassMap;;
@end
@protocol SYPropertyCache
@end

