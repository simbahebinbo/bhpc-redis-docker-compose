#!/bin/bash

#删除已停止的容器 删除卷

# 当前项目的容器名
containers=("redis-standalone" "redis-replication-master" "redis-replication-slave" \
            "redis-sentinel-master" "redis-sentinel-slave" "redis-sentinel" \
            "redis-cluster-1" "redis-cluster-2" "redis-cluster-3" \
            "redis-cluster-4" "redis-cluster-5" "redis-cluster-6")

# 删除已退出的容器
for container_name in "${containers[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    container_status=$(docker inspect -f '{{.State.Status}}' $container_name 2>/dev/null)
    if [ "$container_status" = "exited" ] || [ "$container_status" = "created" ]; then
      echo "删除容器: $container_name"
      docker rm $container_name 2>/dev/null
    fi
  fi
done

# 删除当前项目的卷（通过 docker compose down -v）
echo "删除当前项目的卷..."
docker compose down -v --remove-orphans
