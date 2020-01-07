# 应用编排与管理：核心原理

## K8s资源对象

+ Spec： 期望的状态
+ Status： 观测到的状态
+ Metadata：
  + Labels： 标示型的键值对，作用：用于筛选资源和查询资源
  + annotations
  + Ownerference：所有者，例如Pod的ownref指向创建它的replicas



## 控制器模式

控制循环：

+ 各组件独立自主的运行
+ 不断使系统的状态趋近spec

