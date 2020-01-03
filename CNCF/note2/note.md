# Kubernetes 核心概念

## 什么是Kubernetes

+ 工业级容器编排平台（舵手）
+  核心功能：
  + 服务发现与负载均衡
  + 容器自动装箱 scheduling
  + 存储编排
  + 自动容器恢复（容器不可用，K8s进行恢复，通过节点健康检查）
  + 应用自动发布与回滚
  + 配置与密文管理
  + 批量执行
  + 水平伸缩：业务负载检查能力，如果CPU负载过高，或者时间响应过长，会自动创建多个业务的副本，对业务进行扩容。

## Kubernetes 架构

+ Server client架构：

![image](./figure/1.png)

用户只和Master交互，Master管理Node。

+ Master的组成：

  <img src="figure/2.png" alt="image" style="zoom:67%;" />

  + API server：处理api操作，所有的组件都和API server连接，依赖API server进行消息传递
  + Controller：对集群状态进行管理：自动修复容器，自动水平扩张等
  + Scheduler：调度器：完成调度操作，把容器根据申请的资源找到合适的节点进行放置
  + etcd：存储系统，存储集群的元信息

+ Node：![image](figure/3.png)

  + pod中运行一个或多个容器
  + pod由kubelet运行，通过Api server接受pod所需的状态，提交到Container runtime，在OS上创建起容器。
  + 依赖Storage plugin和Network plugin进行存储和网络操作
  + Kube-proxy：集群的网络代理，组件Cluster Network

+ 例子：![image](figure/4.png)

  + 用户通过UI或CLI提交创建Pod的请求到Api server
  + Api Server 将请求信息写入etcd
  + Scheduler通过watch机制，得知有一个pod要被调度
  + Scheduler决策，想APi server提交：这个pod要调度到某一个node上
  + Api server将信息写入etcd
  + 相应节点Kubelet得到通知，将请求提交到Container Runtime，配合Storage plugin和network plugin，将容器运行。



## K8s核心概念

+ pod：
  + 最小调度以及资源单元
  + 由一个或者多个容器组成
  + 定义容器的运行方式
  + 提供给容器共享的运行环境（网络、进程空间：pod与pod之间是有隔离的）
+ Volume：
  + 声明在Pod中容器可访问的文件目录
  + 可以被挂载在Pod中一个或者多个容器的指定路径下
  + 支持多种后端存储的抽象：本地、分布式（ceph，nfs...），云存储
+ Deployment：
  + 定义一组pod的副本数目，以及版本
  + 通过Controller维护Pod的数目，自动恢复Pod的数目
  + 通过Controller指定策略控制版本：滚动升级，回滚
+ Service：
  + 提供访问一个或多个Pod实例的稳定访问地址
  + 支持多种访问方式：1）ClusterIP 2）NodePort 3）LoadBalancer 
+ Namespace：
  + 集群内部的逻辑隔离
  + 每个资源都属于一个Namespace
  + 同一个Namespace中的资源命名唯一
  + 不同Namespace的资源可以重名



## K8s API的基础知识

+ Http + JSON/YAML

  用户通过http访问api，访问到的内容是Json。

<img src="figure/5.png" alt="image" style="zoom: 50%;" />

+ Label：![image](figure/6.png)
  + 一组Key：value
  + 可以被selector所查询：通过label对资源进行筛选
  + 资源集合的默认表达形式：例如一个service对应哪些Pod就是通过Label selector来描述