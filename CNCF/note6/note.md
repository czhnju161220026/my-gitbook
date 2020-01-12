

# 应用编排与管理： Job与DaemonSet

## 1. Job

### 1.1 背景问题

虽然我们可以直接通过Pod来运行任务进程，但是这样会带来很多问题：

1. 如何保证Pod内的进程正确的结束？
2. 如果进程运行失败，如何重试
3. 如何管理多个任务，且任务之间有相互的依赖关系
4. 如何并行运行任务，并管理他们的队列大小



### 1.2 Job：管理任务的控制器

Job可以帮助我们做什么：

1. 创建一个或多个Pod，确保确定数量的Pod可以成功地运行终止
2. 跟踪Pod状态，根据配置，及时重试失败的Pod
3. 确定依赖关系，保证上一个任务运行完毕后，再运行下一个任务
4. 控制任务的并行度，根据配置确保Pod队列大小

### 1.3 典型的Job yaml模版

``` yaml
# controllers/job.yaml

apiVersion: batch/v1
kind: Job
metadata:
  name: calculate-pi
# Job的规格
spec:
  # 指定Job中Pod的规格
  template:
    spec:
      containers:
      - name: pi-container
        image: pi
        name: pi-image
        imagePullPolicy: IfNotPresent
      restartPolicy: OnFailure # 可以是Never， Always， OnFailure
  backoffLimit: 4  #重试次数
```



### 1.4 并行运行的Job

我们可以指定Job的数目，以及并行度

``` yaml
# controllers/para_jobs.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: calculate-pi
# Job的规格
spec:
  # 指定Job中Pod的规格
  completions: 8
  parallelism: 3
  template:
    spec:
      containers:
      - name: pi-container
        image: pi
        name: pi-image
        imagePullPolicy: IfNotPresent
      restartPolicy: OnFailure # 可以是Never， Always， OnFailure
  backoffLimit: 4  #重试次数
```



### 1.5 定时Job CronJob

CronJob是一种特殊的Job，可以通过schedule来控制何时执行，schedule和 Linux crontab的格式相同

``` yaml
# controllers/cronjob.yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: python:3.6
            imagePullPolicy: IfNotPresent
            args:
            - python 
            - -c
            - "print('hello world')"
          restartPolicy: OnFailure
  startingDeadlineSeconds: 10
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 3
```

定时任务可以用来做定时的清理工作

### 1.6 架构设计

<img src="./figure/1.png" alt="1" style="zoom:67%;" />

#### 1.6.1 管理模式

1. JobController 负责根据配置创建Pod
2. JobController 负责跟踪Pod状态
3. JobController 会自动添加label来跟踪对应的pod，并根据配置，并行或者顺序的创建Pod



#### 1.6.2 Job 控制器

<img src="./figure/2.png" alt="2" style="zoom:50%;" />



### 1.7 Job实践

我们通过Job运行一个计算圆周率的任务：

``` python 
# train.py
if __name__ == '__main__':
    pi=0
    N=50000
    for i in range(N):
        pi+=1/pow(16,i)*(4/(8*i+1)-\
            2/(8*i+4)-1/(8*i+5)-1/(8*i+6))
    print(pi)
```

``` dockerfile
# docker file 
FROM python:3.6
COPY train.py /app/train.py
WORKDIR /app
CMD ["python", "train.py"]
```

将代码构建为镜像pi，然后编写一个yaml文件启动Job。

#### 1.7.1 普通Job

``` yaml
# job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: calculate-pi
# Job的规格
spec:
  # 指定Job中Pod的规格
  template:
    spec:
      containers:
      - name: pi-container
        image: pi
        name: pi-image
        imagePullPolicy: IfNotPresent
      restartPolicy: OnFailure # 可以是Never， Always， OnFailure
  backoffLimit: 4  #重试次数
```

``` shell

$ k apply -f job.yaml
job.batch/calculate-pi created
$ k get jobs 
NAME           COMPLETIONS   DURATION   AGE
calculate-pi   1/1           23s        31s
$ k get pods 
NAME                 READY   STATUS      RESTARTS   AGE
calculate-pi-rtjlw   0/1     Completed   0          35s
$ k logs calculate-pi-rtjlw -n default 
3.141592653589793
```



#### 1.7.2 并行运行的Job

``` yaml
# para-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: calculate-pi
# Job的规格
spec:
  # 指定Job中Pod的规格
  completions: 8
  parallelism: 3
  template:
    spec:
      containers:
      - name: pi-container
        image: pi
        name: pi-image
        imagePullPolicy: IfNotPresent
      restartPolicy: OnFailure # 可以是Never， Always， OnFailure
  backoffLimit: 4  #重试次数
```



``` shell
$ k apply -f para-job.yaml 
job.batch/calculate-pi created
$ k get jobs 
NAME           COMPLETIONS   DURATION   AGE
calculate-pi   0/8           16s        16s
$ k get pods -n default 
NAME                 READY   STATUS    RESTARTS   AGE
calculate-pi-9qrgj   1/1     Running   0          28s
calculate-pi-pdx5q   1/1     Running   0          28s
calculate-pi-vwt2k   1/1     Running   0          28s
$ k get pods -n default        
NAME                 READY   STATUS              RESTARTS   AGE
calculate-pi-8zqpr   1/1     Running             0          5s
calculate-pi-9qrgj   0/1     Completed           0          41s
calculate-pi-br96q   0/1     ContainerCreating   0          3s
calculate-pi-ctwfk   0/1     ContainerCreating   0          2s
calculate-pi-pdx5q   0/1     Completed           0          41s
calculate-pi-vwt2k   0/1     Completed           0          41s
$ k get jobs 
NAME           COMPLETIONS   DURATION   AGE
calculate-pi   8/8           101s       2m28s
```

我们指定并发数目是3，每当一批Pod运行结束后，会启动下一批的3个pod，直到任务完成

#### 1.7.3 定时任务

``` yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: python:3.6
            imagePullPolicy: IfNotPresent
            args:
            - python 
            - -c
            - "print('hello world')"
          restartPolicy: OnFailure
  startingDeadlineSeconds: 10
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 3
```

``` shell
$ k apply -f cronjob.yaml 
cronjob.batch/hello created
$ k get jobs 
No resources found.
$ k get jobs 
NAME               COMPLETIONS   DURATION   AGE
hello-1578648480   1/1           2s         4s
$ k get pods -n default 
NAME                     READY   STATUS      RESTARTS   AGE
hello-1578648480-xnckr   0/1     Completed   0          11s
$ k logs hello-1578648480-xnckr -n default 
hello world
```



## 2 DaemonSet

### 2.1 背景问题

我们可以让每个集群内的节点或者指定某些节点运行相同的一个Pod吗？

1. 如何保证每个节点都运行一个Pod
2. 如果新节点加入集群，如何感知并部署对应的Pod
3. 如果有节点退出，如何删除对应的Pod
4. 如果Pod状态异常，如何监控并恢复Pod的状态

### 2.2 DaemonSet 守护进程控制器

DaemonSet可以做什么？

1. 保证集群内的每一个（或者一些）节点都运行一组相同的Pod
2. 跟踪集群节点状态，保证新加入的节点自动创建对应的Pod
3. 跟踪节点状态，保证移除的节点删除对应的Pod
4. 跟踪Pod的状态，保证每个Pod都处于运行状态

### 2.3 DaemonSet 语法

``` yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels: 
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
      spec:
        containers:
        - name: fluentd-elasticsearch
          image: fluentd/fluentd: v1.4-1
```

适用场景：

1. 集群存储进程： ceph， glusterd
2. 日志收集进程： fluentd， logstash
3. 需要在每个节点上运行的监控收集器