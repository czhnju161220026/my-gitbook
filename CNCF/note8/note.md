# 持久化存储

## 1. Pod Volumes

### 1.1 问题来源

+ 如果一个Pod中的某一个容器异常退出，被kubelet拉起，如何保证之前产生的数据不丢失
+ 同一个Pod的多个容器如何共享数据

### 1.2 K8s Volumes类型

+ 本地存储：hostPath， emptyDir..
+ 网络存储：
  + in-tree(实现整合在k8s内部)：awsElasticBlockStore/nfs/gcePersistentDisk...
  + out-of-tree: flexvolumes/csi等网络存储plugins
+ Projected Volumes: secret/configmap等配置信息
+ PVC和PV体系（重要）



## 2. 为什么需要持久化存储（PersistentVolume）

**Pod Volumes的功能不够强大**：Pod中声明的Volume的生命周期与Pod相同，Pod销毁后，Pod中声明的Volume的数据会丢失，在以下场景会遇到问题：

1. Pod销毁重建（例如Deployment管理Pod镜像升级）
2. 宿主机故障迁移（如StatefulSet管理的Pod带远程volume迁移）
3. 多个Pod共享同一个volume
4. 数据存储快照等功能。

对于这些场景，使用Pod Volume难以表达volume复用/共享的语义，新功能很那实现。

因此，如果可以将存储与计算分离，使用不同的组件管理存储与计算资源，解耦Pod与Volume的生命周期关联，就可以很好的解决上述场景中的问题。



## 3. PV与PVC架构的设计

既然有了PV，为什么要设计PVC（PersistentVolumeClaim）？

1. **职责分离**：PVC中只声明所需的存储size，访问模式（单node独占 or 多node， 只读还是可读可写）而不关心存储的实现细节，PV和其对应的后端存储信息则交给cluster admin进行统一运维与管控，安全访问的策略更加容易控制。
2. **PVC简化了User对存储对需求，PV才是存储的实际信息的承载体**：通过kube-controller-manager中的PersistentVolumeController将PVC与合适的PV绑定到一起，从而满足用户对存储的实际需求。
3. PVC像是面向对象编程抽象出来的接口，而PV是具体的实现。



### 3.1 Static Volume Provisioning

<img src="figure/1.png" alt="image" style="zoom:67%;" />

**静态存储供给**需要集群管理员预先规划一些PV，然后用户通过PVC来使用所需的PV。但是这样有许多不足：用户的需求是多样化的，很容易导致User提交的PVC找不到合适的PV对象。例如有10G和30G的PV，但是用户希望使用20G的。

因此更好的方式是下面的**动态存储供给**。

### 3.2 Dynamic Volume Provisioning

<img src="figure/2.png" alt="image" style="zoom:67%;" />

**动态存储供给**中，集群管理员只创建不同类型存储的模板（StorageClass），而User在PVC中指定使用哪种模板，以及所需空间，访问方式等参数。然后K8s结合StorageClass和PVC，动态的创建PV对象提供给用户使用。

在K8s的文档中，给出了如何创建StorageClass。

``` yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
allowVolumeExpansion: true
mountOptions:
  - debug
volumeBindingMode: Immediate
```

## 4. 用例解读

### 4.1 PodVolumes

#### 4.1.1 HostPath

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
    - name: test-container
      image: ubuntu
      command: ["touch","/etc/data/test.test.test"]
      volumeMounts:
      - name: volume1
        mountPath: "/etc/data"
  volumes:
    - name: volume1
      hostPath:
        path: /User/cui/Desktop
  restartPolicy: Never
```

HostPath指定使用宿主机上的路径作为Volume，即使Pod被删除，但是Volume中的信息仍然存留在宿主机上。

#### 4.1.2 EmptyDir

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptyDir-path
spec:
  containers:
    - name: test-container
      image: ubuntu
      command: ["touch","/etc/data/test.test.test"]
      volumeMounts:
      - name: volume1
        mountPath: "/etc/data"
  volumes:
    - name: volume1
      emptyDir: {}
  restartPolicy: Never
```

emptyDir使用宿主机上的一个临时目录，其生命周期和Pod一样。

### 4.2 Dynamic Volume Provisioning

以Dlkit的集群为例，它的StorageClass定义如下：

``` yaml
# [czh@n167 ~]$ k get storageclass cephfs -o yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  creationTimestamp: "2019-12-29T09:09:14Z"
  name: cephfs
  resourceVersion: "216329"
  selfLink: /apis/storage.k8s.io/v1/storageclasses/cephfs
  uid: 3a225dd9-41e8-4767-a511-d1cfaf7e3db1
parameters:
  adminId: admin
  adminSecretName: ceph-secret-admin
  adminSecretNamespace: cephfs
  claimRoot: /dlkit-volumes
  monitors: 210.28.132.168:6789,210.28.132.169:6789,210.28.132.170:6789
provisioner: ceph.com/cephfs
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

使用Cephfs作为底层存储的提供者。



对于WorkSpace中的每个任务而言，都会生成一个PVC，来获得所需的PV。我们查看所有的PVC

![image](figure/3.png)

查看具体某一个PVC

``` yaml
# [czh@n167 ~]$ k get persistentvolumeclaim dlkit-workspace-test -n dlkit-resources -o yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: ceph.com/cephfs
  creationTimestamp: "2019-12-29T12:48:27Z"
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    dlkit.njuics.cn/name: test
    dlkit.njuics.cn/type: workspace
  name: dlkit-workspace-test
  namespace: dlkit-resources
  ownerReferences:
  - apiVersion: njuics.cn/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: Workspace
    name: test
    uid: c70beebb-614e-49ec-a1bf-10415c610c39
  resourceVersion: "269997"
  selfLink: /api/v1/namespaces/dlkit-resources/persistentvolumeclaims/dlkit-workspace-test
  uid: 1f12135e-69dd-424e-97ac-c008e0b2981a
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: cephfs
  volumeMode: Filesystem
  volumeName: pvc-1f12135e-69dd-424e-97ac-c008e0b2981a
status:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  phase: Bound
```

在这个PVC的spec中，指定了size，accessModes等参数，以及使用的storageClass

还可以看到对应的PV对象的名称。

我们查看这个pv对象：

``` yaml
[czh@n167 ~]$ k get persistentvolume pvc-1f12135e-69dd-424e-97ac-c008e0b2981a -n dlkit-resources -o yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    cephFSProvisionerIdentity: cephfs-provisioner-1
    cephShare: kubernetes-dynamic-pvc-81ffa895-2a39-11ea-9e0c-8ec5540e92a0
    pv.kubernetes.io/provisioned-by: ceph.com/cephfs
  creationTimestamp: "2019-12-29T12:48:27Z"
  finalizers:
  - kubernetes.io/pv-protection
  name: pvc-1f12135e-69dd-424e-97ac-c008e0b2981a
  resourceVersion: "269995"
  selfLink: /api/v1/persistentvolumes/pvc-1f12135e-69dd-424e-97ac-c008e0b2981a
  uid: 735eb06e-520b-4fbb-bac1-86eb2fc3772b
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  cephfs:
    monitors:
    - 210.28.132.168:6789
    - 210.28.132.169:6789
    - 210.28.132.170:6789
    path: /dlkit-volumes/kubernetes/kubernetes-dynamic-pvc-81ffa895-2a39-11ea-9e0c-8ec5540e92a0
    secretRef:
      name: ceph-kubernetes-dynamic-user-81ffa8f9-2a39-11ea-9e0c-8ec5540e92a0-secret
      namespace: cephfs
    user: kubernetes-dynamic-user-81ffa8f9-2a39-11ea-9e0c-8ec5540e92a0
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: dlkit-workspace-test
    namespace: dlkit-resources
    resourceVersion: "269946"
    uid: 1f12135e-69dd-424e-97ac-c008e0b2981a
  persistentVolumeReclaimPolicy: Delete
  storageClassName: cephfs
  volumeMode: Filesystem
status:
  phase: Bound
```

