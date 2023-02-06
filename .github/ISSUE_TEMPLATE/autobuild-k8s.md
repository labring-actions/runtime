---
name: 构建Kubernetes集群镜像
about: 根据分支目录构建集群镜像并推送到镜像仓库
title: '【Auto-build】kubernetes'
assignees: ''

---

```
Usage:
   /kube [sealosVersion]             # all containerd + all docker (increment)
   /containerd [sealosVersion]              # all containerd
   /docker [sealosVersion]       # all docker
   /single_part4 [sealosVersion] # all containerd + all docker (increment) for part4
   /single_containerd_part4 [sealosVersion]        # containerd for part4
   /single_docker_part4 [sealosVersion] # docker for part4
Example:
   /kube 4.1.5
   /containerd 4.1.5
   /docker 4.1.5
   /single_part4 4.1.5
   /single_containerd_part4 4.1.5
   /single_docker_part4 4.1.5
```
