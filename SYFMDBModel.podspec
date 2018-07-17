Pod::Spec.new do |s|

# 库名可以通过pod search命令搜索到
s.name         = "SYFMDBModel"

# 库的版本号，需要在对应版本分支上添加上对应版本的标签tag，标签不对在上传的时候会出问题
s.version      = "0.0.3"

# 库的概述，可在”pod search 库名”命令时看到
s.summary      = "对FMDB进行扩展"

# 库的具体描述，文字长度应比概述要长，否则会出现警告
s.description  = <<-DESC
对FMDB进行扩展, 效果是可以对对象进行存储并从数据库中得到对象
DESC

# 库的运行平台，不加会造成警告，原因是在手表及电脑端无法实现
s.platform     = :ios, '8.0'

# 库的首页
s.homepage     = "https://github.com/gushengya/SYFMDBModel"

# 许可声明必填， 需在跟库文件夹同级别路径创建一个名称为LICENSE的文件并添加许可声明
s.license      = { :type => 'MIT', :file => 'LICENSE' }

# 用户名以及邮箱, 标记所有人
s.author             = { "gushengya" => "759705236@qq.com" }

# 项目源代码位置一般就是一个github地址(:commit => "686868" 表示将这个Pod版本与Git仓库中某个commit绑定、:tag => 1.0.0表示与某个版本的commit绑定)
s.source       = { :git => "https://github.com/gushengya/SYFMDBModel.git", :commit => "02b0931" }

# 项目主要文件(*表示匹配所有文件、*.h表示匹配所有.h文件、*.{h,m}表示匹配所有.h和.m文件、**表示匹配所有子目录)
s.source_files  = "SYFMDBModel/**/*.{h,m}"

# 依赖的frameworks
s.frameworks = 'UIKit'

# 依赖的lib
s.libraries    = 'objc', 'sys'

# 依赖第三方pod库 -- 格式为: s.dependency '第三方库名', '版本号'，如有多个以逗号,隔开
s.dependency 'FMDB', '2.7.2'

end
