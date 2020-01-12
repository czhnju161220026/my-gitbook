# 应用编排与管理 ：Deployment

## 1. 需求来源

<img src="figure/1.png" alt="image" style="zoom: 67%;" />

如果不对Pod进行组织，直接管理集群中所有的Pod，那么会导致如下的问题：

+ 如何保证集群内可用Pod的数量
+ 如何为所有的Pod更新镜像版本（逐个更新？）
+ 更新的过程中，如何保证服务可用性
+ 更新过程中，发现问题如何快速回滚



## 2. Deployment：管理部署发布的控制器

Deployment可以帮助我们完成什么任务？

+ 定义一组Pod的期望数量，controller会维持Pod数量与期望数量一致
+ 配置Pod的发布方式，controller会按照给定的策略更新Pod，保证更新过程中不可用的Pod的数量在限定范围内
+ 如果新版本有问题，支持迅速回滚



## 3. 管理模式

<img src="figure/2.png" alt="image" style="zoom:50%;" />

Deployment只负责管理不同版本的ReplicaSet，由ReplicaSet管理Pod副本数目。

每个ReplicaSet都对应了Deployment template的一个版本

一个ReplicaSet下的Pod都是相同的版本。



## 4. 实践

### 4.1 镜像准备

我们准备三个版本的<code>hello</code>镜像，基于node.js镜像构建

``` dockerfile
FROM node:6.14.3
EXPOSE 8080
COPY server.js .
CMD node server.js
```

``` javascript
var http = require('http');

var handleRequest = function(request, response) {
  console.log('Received request for URL: ' + request.url);
  response.writeHead(200);
  response.end('Hello World from node:6.14.3!');
};
var www = http.createServer(handleRequest);
www.listen(8080);

```

这三个镜像的功能相同，都是在页面上显示Hello World字段，不同的是所使用的Node.js的版本不同。

镜像构建完成：

``` shell
$ docker image ls | grep hello
hello                                                                             v0.3                3c410a02a153        16 hours ago        660MB
hello                                                                             v0.2                4e8731465f2b        16 hours ago        660MB
hello                                                                             v0.1                30fae02e5b5b        16 hours ago        660MB
```

### 4.2 建立部署

#### 4.2.1 模板

一个典型的Deployment的模板：

<img src="figure/4.png" alt="image" style="zoom: 50%;" />



#### 4.2.2 准备yaml文件：

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-dep
  name: hello-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-pod
  template:
    metadata:
      labels:
        app: hello-pod
    spec:
      containers:
      - image: hello:v0.1
        name: hello
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
```

我们要求集群创建3个Pod的副本，指定Pod中容器使用v0.1版本的镜像

#### 4.2.3 创建Deployment

然后创建Deployment

``` shell
$ kubectl apply -f dep.yaml 
deployment.apps/hello-deployment created
```

查看Deployment和Pod

``` shell
$ k apply -f dep.yaml 
deployment.apps/hello-deployment created
$ k get deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
hello-deployment   3/3     3            3           9s
$ k get pods -n default
NAME                                READY   STATUS    RESTARTS   AGE
hello-deployment-6cc595c5cf-b52j8   1/1     Running   0          30s
hello-deployment-6cc595c5cf-p7zkl   1/1     Running   0          30s
hello-deployment-6cc595c5cf-ttgz7   1/1     Running   0          30s
```

#### 4.2.4 暴露服务

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
  labels:
    app: hello-svc
spec:
  type: NodePort
  ports:
    - port: 8080
      nodePort: 30001
  selector:
    app: hello-pod
```

``` shell
$ k apply -f service.yaml 
service/hello-svc created
$ k get service
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
hello-svc    NodePort    10.104.208.35   <none>        8080:30001/TCP   23s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP          6d6h
```



<img src="figure/5.png" alt="image-20200110144931790" style="zoom: 67%;" />

### 4.3 对Deployment进行管理

#### 4.3.1 升级

我们通过kubectl edit来修改deployment的yaml文件，对容器所使用的镜像版本进行升级：

``` shell
$ k edit deployment hello-deployment
deployment.apps/hello-deployment edited
$ k get pods -n default
NAME                                READY   STATUS        RESTARTS   AGE
hello-deployment-5684b86678-bddhb   1/1     Running       0          6s
hello-deployment-5684b86678-dfh9t   1/1     Running       0          3s
hello-deployment-5684b86678-hmgxf   1/1     Running       0          8s
hello-deployment-6cc595c5cf-b52j8   1/1     Terminating   0          8m58s
hello-deployment-6cc595c5cf-p7zkl   1/1     Terminating   0          8m58s
hello-deployment-6cc595c5cf-ttgz7   1/1     Terminating   0          8m58s
$ k get replicaset
NAME                          DESIRED   CURRENT   READY   AGE
hello-deployment-5684b86678   3         3         3       2m26s
hello-deployment-6cc595c5cf   0         0         0       11m
```

<img src="figure/6.png" alt="image-20200110145435848" style="zoom:67%;" />



可以发现，Deployment新建一个replicaset，并将旧的replicaset中的Pod终止并删除。

每一个Replicaset都对应一个历史的版本。

#### 4.3.2 扩容

我们再进行一次升级，并将replica数目扩展为5个。

``` shell
$ k edit deployment hello-deployment
deployment.apps/hello-deployment edited
$ k get pods -n default
NAME                                READY   STATUS        RESTARTS   AGE
hello-deployment-5684b86678-76tkf   1/1     Terminating   0          11s
hello-deployment-5684b86678-bddhb   1/1     Terminating   0          4m40s
hello-deployment-5684b86678-dfh9t   1/1     Terminating   0          4m37s
hello-deployment-5684b86678-hmgxf   1/1     Terminating   0          4m42s
hello-deployment-6b69d645bf-9ncd8   1/1     Running       0          11s
hello-deployment-6b69d645bf-dwfr5   1/1     Running       0          11s
hello-deployment-6b69d645bf-jrdpv   1/1     Running       0          11s
hello-deployment-6b69d645bf-mc6lf   1/1     Running       0          6s
hello-deployment-6b69d645bf-plbp4   1/1     Running       0          6s
```

#### 4.3.3 回滚

1. 回滚到上一个版本

   ``` shell
   kubectl rollout undo deplyment.v1.apps/hello-deployment
   ```

2. 回滚到某一个版本

   ``` shell
   kubectl rollout history deployment.v1.apps/hello-deployment # 查看历史版本
   kubectl rollout undo deployment.v1.apps/hello-deployment --to-revision=2 # 回滚到指定版本
   ```

``` shell
$ k rollout history deployment.v1.apps/hello-deployment
deployment.apps/hello-deployment 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>

$ k rollout undo  deployment.v1.apps/hello-deployment --to-revision=1
deployment.apps/hello-deployment rolled back
```

发现回滚后到副本数目仍然是扩容后的5个，但是每个pod的容器所使用的镜像回滚到了最终版本。说明回滚只更新镜像，不会更改副本数目。

另外，可以控制历史版本的个数。