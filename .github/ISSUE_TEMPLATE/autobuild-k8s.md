---
name: 构建Kubernetes集群镜像
about: 根据分支目录构建集群镜像并推送到镜像仓库
title: '【Auto-build】kubernetes'
assignees: ''

---

```
Usage:
   /kube [sealosVersion]                     # all images for containerd, cri-o, docker
   /containerd [sealosVersion]               # all images for containerd
   /cri-o [sealosVersion]                    # all images for cri-o
   /docker [sealosVersion]                   # all images for docker
   /single_part4 [sealosVersion]             # all images for containerd, cri-o, docker with part4
   /single_containerd_part4 [sealosVersion]  # all images for containerd with part4
   /single_cri-o_part4 [sealosVersion]       # all images for cri-o with part4
   /single_docker_part4 [sealosVersion]      # all images for docker with part4
Example:
   /kube 4.1.5
   /containerd 4.1.5
   /cri-o 4.1.5
   /docker 4.1.5
   /single_part4 4.1.5
   /single_containerd_part4 4.1.5
   /single_cri-o_part4 4.1.5
   /single_docker_part4 4.1.5
```
