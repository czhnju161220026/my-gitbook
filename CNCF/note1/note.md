# 容器基本概念

 ## 容器与镜像

### 容器

+ OS上的进程：相互可见，可相互通信，使用同一个文件系统和系统资源。**问题**：权限高的进程可以攻击其他进程（增删改查）；进程依赖冲突；资源抢占问题。

+ 容器：namespace提供资源视图隔离；chroot提供独立的文件系统；cgroup：控制资源使用率

  ![image-20200103165746609](/Users/cui/WorkSpace/DockerSpace/my-gitbook/CNCF/note1/figure/1.png)

  其实从代码角度理解是最容易的。就是在进程的struct里面加多了几个变量用来区分uts,ipc等等，比如两个进程管理uts的变量一样，那么就共享hostname 和 NIS信息，如果不一样就各自玩各自的。IPC，如果一样的话，一个进程创建的 消息队列，另一个进程也能看到。不一样的话就看不到。

  **容器：一个视图隔离，资源可限制，独立文件系统的进程集合**

  + 视图隔离：能看到部分进程，独立主机名
  + 控制资源使用率：比如设定最大内存大小，CPU使用个数
  + 独立文件系统

### 镜像：

+ 容器运行所需的所有文件集合。使用Dockerfile构建。
+ 每个步骤导致文件系统变化（changeset）
+ 镜像分层，镜像之间可以相互复用。
+ 好处：镜像分层，便于分发。如果本地已经有某一层，就不用下载。可以减小镜像大小，节约系统资源。

``` dockerfile
# based on golang alpine
FROM golang:1.12-alpine
# 设定工作目录 $PWD-> /go/src/app
WORKDIR /go/src/app
# 拷贝文件
COPY . .
# 安装
RUN go get -d -v ./...
# 安装
RUN go install -v ./...
# RUN the app
CMD ["app"]
```

+ 中心存储服务(docker registry): docker push & pull

+ docker run: [--name] [-d] [--rm] [-v] [-p] image [cmd]

## 容器的生命周期

+ 单进程模式：init进程的生命周期=容器生命周期；可以通过exec进入容器

+ 数据持久化：有的容器在运行时会产生重要数据（mysql，ML）。数据卷：生命周期独立于容器的生命周期。docker volume ， bind

+ 如何使用数据卷：

  + bind：把宿主机上的目录绑定到容器内

    ``` shell
    $ docker run -v "宿主机目录：容器目录" ...
    ```

  + Volume: 让docker容器引擎去处理

    ``` shell
    $ docker create volume demo
    $ docker run -v demo:/tmp ...
    ```

    volume的好处在于可以移植，可以通过docker volume命令进行管理。

    ``` shell
    (base) ➜  ~ docker volume -h
    Flag shorthand -h has been deprecated, please use --help
    
    Usage:	docker volume COMMAND
    
    Manage volumes
    
    Commands:
      create      Create a volume
      inspect     Display detailed information on one or more volumes
      ls          List volumes
      prune       Remove all unused local volumes
      rm          Remove one or more volumes
    ```

    

## 容器 vs VM

+ VM: hypervisior虚拟化技术，模拟硬件资源，需要Guest OS；隔离效果更好，但是消耗更多的资源。
+ 容器：无Guest，启动快，进程级别的隔离。（只是需要一个独立文件系统，提供运行需要的文件），隔离效果弱于VM。

![image-20200103184443726](/Users/cui/WorkSpace/DockerSpace/my-gitbook/CNCF/note1/figure/2.png)