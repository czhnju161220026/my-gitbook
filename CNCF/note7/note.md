# 应用编排与管理： 应用配置管理

## 1. 背景

我们可以通过Pod来承载Container，但是在实际情况下，还要解决以下的问题：

1. 如何在不改变容器镜像的情况下，改变容器内部的配置，如配置文件，环境变量等（ConfigMap)
2. 敏感信息等存储与使用，例如密码，token（Secret）
3. 集群中Pod自我身份认证 （ServiceAccount）
4. 容器运行的资源配置管理（Resources）
5. 容器运行的安全管控（SecurityContext）
6. 容器启动的前置条件 （InitContainers）

这里，我们主要介绍ConfigMap和Secret

## 2. ConfigMap

ConfigMap主要管理容器运行所需要的配置文件，环境变量，命令行参数等可变配置。用于解耦容器镜像和可变配置，从而保障工作负载的可移植性。

ConfigMap创建命令：<code>kubectl create configmap [Name] [Data]</code>

其中Data指定文件或者目录，或者指定键值对。

### 2.1 创建一个ConfigMap

#### 2.1.1 通过键值对的方式

``` shell
$ k create configmap my-config-1 --from-literal=my.how=very --from-literal=my.what=eat 
configmap/my-config-1 created

$ k get configmap -n default                                                 
NAME          DATA   AGE
my-config-1   2      10s
                                                                                       
$ k describe configmap my-config-1 -n default                                
Name:         my-config-1
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
my.what:
----
eat
my.how:
----
very
Events:  <none>

```

在创建了configMap后，我们可以在Pod中使用它，常见的方式是用configmap中的键值对来设置环境变量。

准备一个yaml文件用来创建Pod，并使用我们定义的configmap

``` yaml
# pod-with-config1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-map-test-pod1
spec:
  containers:
    - name: test-container
      image: ubuntu
      command: ["bin/bash", "-c", "env"]
      env:
        - name: SPECIAL_LEVEL_KEY
          valueFrom:
            configMapKeyRef:
              name: my-config-1
              key: my.how
  restartPolicy: Never

```

创建这个Pod，并查看命令的输出，就可以发现，环境变量已经被设置为我们定义的configmap中的值

``` shell
$ k apply -f pod-with-config1.yaml         
pod/config-map-test-pod1 created
 
$ k logs config-map-test-pod1 -n default   
...
SPECIAL_LEVEL_KEY=very
...
```



#### 2.1.2 通过文件的方式

我们可以指定configmap使用的配置文件，然后在Pod中将它挂载到某个配置文件目录即可。

我们准备一个json配置文件：

``` json
// my-conf.json
{
    "Port": 1234,
    "Network": "192.168.1.1",
    "CMD": ["do","some","thing"]
}
```



然后创建configmap

``` shell
$ k create configmap my-config-2 --from-file=/Users/cui/WorkSpace/DockerSpace/configmap-example/my-conf.json -n default           
configmap/my-config-2 created
                                                                                                                                             
$ k describe configmap my-config-2 -n default                                                                                     
Name:         my-config-2
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====

my-conf.json:
----

{
    "Port": 1234,
    "Network": "192.168.1.1",
    "CMD": ["do","some","thing"]
}
Events:  <none>
```



从文件创建的configmap，我们可以将它挂载到Pod的指定目录下：

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-test-pod2
spec:
  containers:
    - name: test-container
      image: ubuntu
      command: ["cat", "/etc/config/my-conf.json"]
      volumeMounts:
      - name: config-volume
        mountPath: "/etc/config"
  volumes:
    - name: config-volume
      configMap:
        name: my-config-2
  restartPolicy: Never
```

然后查看Pod的运行情况可以发现，配置文件确实被挂载到了Pod中

``` shell
$ k apply -f yaml/pod-with-config2.yaml    
pod/configmap-test-pod2 created
                                                     
$ k logs configmap-test-pod2 -n default    
{
    "Port": 1234
    "Network": "192.168.1.1",
    "CMD": ["do","some","thing"]
}% 
```



### 2.2 ConfigMap使用注意点

+ ConfigMap文件大小限制：1MB（ETCD要求）

+ Pod只能引用相同namespace中的configMap

+ Pod引用的ConfigMap不存在时，Pod无法创建成功

+ 使用envValueFrom方式来配置环境变量时，如果ConfigMap中的某些key被认为无效，那么该环境变量不会被注入容器，但是Pod可以创建成功

## 3. Secret

### 3.1 介绍

Secret是在集群中用于储存密码、token等敏感信息使用的资源对象。其中敏感数据使用Base64编码保存，相比于存储在ConfigMap中的明文更规范，更安全。

### 3.2 创建

Secret的创建和ConfiMap类似，手动创建一个Secret <code>kubectl create secret generic [Name] [Data] [Type]</code>, Type默认是Opaque。Data可以是键值对，也可以是文件。

#### 3.2.1 通过键值对创建

``` shell
$ k create secret generic account-secret --from-literal=user=czh --from-literal=pwd=123456
secret/account-secret created
$ k get secret account-secret -n default -o yaml                      
apiVersion: v1
data:
  pwd: MTIzNDU2
  user: Y3po
kind: Secret
metadata:
  creationTimestamp: "2020-01-19T02:24:06Z"
  name: account-secret
  namespace: default
  resourceVersion: "25983"
  selfLink: /api/v1/namespaces/default/secrets/account-secret
  uid: d3e32222-a440-4109-b46d-8daf772103b3
type: Opaque
```

可以看到，键值对信息被加密了。

#### 3.2.2 通过文件创建

``` shell
$ cat my-conf.json                                                    
{
    "Port": 1234,
    "Network": "192.168.1.1",
    "CMD": ["do","some","thing"]
}%                                                                               
$ k create secret generic conf-secret --from-file=my-conf.json        
secret/conf-secret created
                                                                                
$ k get secret -n default                                             
NAME                  TYPE                                  DATA   AGE
account-secret        Opaque                                2      3m16s
conf-secret           Opaque                                1      9s
default-token-7rcvl   kubernetes.io/service-account-token   3      24h
                                                                                
$ k get secret conf-secret -n default -o yaml                         
apiVersion: v1
data:
  my-conf.json: ewogICAgIlBvcnQiOiAxMjM0LAogICAgIk5ldHdvcmsiOiAiMTkyLjE2OC4xLjEiLAogICAgIkNNRCI6IFsiZG8iLCJzb21lIiwidGhpbmciXQp9
kind: Secret
metadata:
  creationTimestamp: "2020-01-19T02:27:13Z"
  name: conf-secret
  namespace: default
  resourceVersion: "26213"
  selfLink: /api/v1/namespaces/default/secrets/conf-secret
  uid: e88451c1-0846-4fcc-bffa-4e2ddf067d22
type: Opaque
```

​	可以看到，文件信息也被加密了。

#### 3.2.3使用Secret

Secret一般被Pod使用，一般通过volume挂载到指定容器目录，供容器业务使用。

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod-test
spec:
  containers:
  - name: test-container
    image: ubuntu
    command: ["ls","/etc/foo/"]
    volumeMounts:
    - name: foo 
      mountPath: "/etc/foo"
      readOnly: true
  volumes:
  - name: foo
    secret:
      secretName: account-secret
```

Secret的data下每一个键都被映射为mountPath下的一个文件。

``` shell
$ k apply -f yaml/pod-with-secret.yaml                                          
pod/secret-pod-test created
                                                                                                                                                                                    
$ k logs secret-pod-test -n default                                             
pwd
user
```



