# Pod与容器设计模式

## 为什么需要Pod

### 容器、Pod

+ 容器的本质：一个视图被隔离，资源受限的进程；容器中pid=1的进程就是应用本身。**单进程模型**
+ 因此管理虚拟机是在管理基础设施，而管理容器就是管理应用本身
+ Kubernetes就是云时代的操作系统，而容器就是操作系统上的进程
+ 在真实的操作系统里，一个程序是由一个进程组管理的。容器类似于进程，而Pod就类似于**进程组**。
+ Pod是K8s分配资源的单位（原子调度单位）

假设有四个需要相互协作的进程需要放在K8s上运行，通常会把他们定义为一个Pod，这个Pod拥有四个容器。

 <img src="figure/1.png" alt="image" style="zoom:50%;" />

### 为什么Pod必须是原子调度单位

+ 举例：两个容器紧密协作，必须共享一些资源：
  + App： 业务容器，写日志文件
  + LogCollector： 转发日志文件
+ 内存需求：
  + App： 1G
  + LogCollector： 0.5G
+ 当前可用内存：
  + NodeA： 1.25G
  + NodeB： 2G
+ 如果App先被调度到了NodeA上，那么LogCollector就无法放在A上
+ 所以，如果以容器为单位调度，会出现Task co-scheduling问题



### 再次理解Pod

+ 亲密关系：两个应用需要运行在一台宿主机上
+ 超亲密关系： 
  + 会发生直接文件交换
  + 通过localhost和Socket文件进行通信
  + 发生频繁的Rpc调用
  + 会共享某些Linux Namespace（一个容器加入另一个容器的Network Namespace）

<img src="figure/2.png" alt="image" style="zoom:50%;" />

### Pod的作用

+ 如何描述超亲密关系
+ 如何对超亲密关系的应用进行调度

## Pod的实现机制

### 要解决的问题

如何高效的共享某些资源和数据

+ 共享网络：在一个Pod里额外起一个Infra Container。其他容器join到Infra Container的Network Namespace。通过Infra Container的方式共享同一个Network Namespace。一个Pod中每一个容器看到的网络设备和Infra容器看到的完全一样。
+ 共享存储：把共享的volume挂载到容器中，那么在容器中，通过共享的volume可以共享存储。

## 详解容器设计模式（解耦+重用）

### 举例：部署一个War包 + Tomcat的应用

+ 方法一： WAR包和Tomcat打包进同一个镜像
  + 缺点：无论是WAR包和Tomcat更新都需要重新制作镜像
+ 方法二：镜像里只打包Tomcat，使用数据卷（hostPath）从宿主机上将WAR包挂载进Tomcat容器
  + 缺点：需要维护一套分布式存储系统（nfs等）
+ 可以使用Sidecar的设计模式：
  + 使用InitContainer来完成将War包拷贝到数据卷到操作
  + 然后在Tomcat容器启动时，InitContainer已经完成了拷贝操作，就可以使用War了



### Sidecar模式：

+ 在Pod中定义专门容器，来执行主业务容器需要的辅助工作
+ 好处：将辅助功能与主业务容器解耦，实现独立发布和能力重用
+ 场景：
  + 原本需要ssh进去执行的脚本
  + 日志收集：业务容器将日志卸载Volume中，Sidecar容器读取volume，将日志转发到远程存储
  + 代理容器：单独写一个代理容器，业务容器只要访问代理容器
  + 适配器容器：Adapter模式，将业务容器暴露出来的接口转换为另一种格式。