---
name: 构建Kubernetes集群镜像
about: 根据分支目录构建集群镜像并推送到镜像仓库
title: '【AIO】kubernetes'
assignees: ''

---

```
Usage:
   /kube [sealosVersion]                     # all images for containerd, cri-o, docker and k3s(v1.24+)
Example:
   /kube 4.4.1 # Image tags such as v1.28.0
   /kube 4.4.0-alpha1 # Image tags such as v1.28-latest
```
