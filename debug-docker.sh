#!/bin/bash

# 查看容器日志

# 当前项目的主要容器名
containers=("redis-standalone" "redis-replication-master" "redis-sentinel-master" \
            "redis-sentinel" "redis-cluster-1" "redis-cluster-2")

for container_name in "${containers[@]}"; do
  docker logs -f $container_name
done
