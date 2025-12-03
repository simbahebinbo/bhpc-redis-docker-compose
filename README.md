### 配置说明

然后根据需要修改 `.env` 文件中的 `REDIS_VERSION` 和 `REDIS_PASSWORD`。

### Redis 部署模式说明

本项目支持 4 种 Redis 部署模式：

1. **单机模式 (Standalone)**
   - 端口: `6380`
   - 容器: `redis-standalone`
   - 适用场景: 开发测试、小规模应用

2. **主从复制模式 (Master-Slave Replication)**
   - 主节点端口: `6381` (容器: `redis-replication-master`)
   - 从节点端口: `6382` (容器: `redis-replication-slave`)
   - 适用场景: 读写分离、数据备份
   - 注意: 无自动故障转移，主节点故障需手动切换

3. **哨兵模式 (Sentinel)**
   - 主节点端口: `6383` (容器: `redis-sentinel-master`)
   - 从节点端口: `6384` (容器: `redis-sentinel-slave`)
   - 哨兵端口: `6385` (容器: `redis-sentinel`)
   - 适用场景: 高可用，自动故障转移
   - 连接方式: 通过哨兵端口 `6385` 连接

4. **集群模式 (Cluster)**
   - 节点端口: `7000-7005` (容器: `redis-cluster-1` 到 `redis-cluster-6`)
   - 集群总线端口: `17000-17005`
   - 适用场景: 大规模数据、高并发、水平扩展
   - 注意: 启动后需要执行集群初始化命令

### 使用方式

* 启动所有模式

```shell
$ ./start-docker.sh
```

* 启动指定模式（示例：只启动单机模式）

```shell
$ docker compose up -d redis-standalone
```

* 启动主从复制模式

```shell
$ docker compose up -d redis-replication-master redis-replication-slave
```

* 启动哨兵模式

```shell
$ docker compose up -d redis-sentinel-master redis-sentinel-slave redis-sentinel
```

* 启动集群模式（需要先启动所有节点，然后初始化集群）

```shell
# 启动所有集群节点
$ docker compose up -d redis-cluster-1 redis-cluster-2 redis-cluster-3 redis-cluster-4 redis-cluster-5 redis-cluster-6

# 初始化集群（3主3从）
$ docker exec -it redis-cluster-1 redis-cli -a 123456 --cluster create \
  127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
  --cluster-replicas 1
```

* 调试镜像

```shell
$ ./debug-docker.sh
```

* 停止镜像

```shell
$ ./stop-docker.sh
```

* 清理镜像

```shell
$ ./clean-docker.sh
```

* 测试镜像

```shell
$ ./test-docker.sh
```

### 连接示例

* 单机模式
```shell
redis-cli -h localhost -p 6380 -a 123456
```

* 主从复制模式（连接主节点）
```shell
redis-cli -h localhost -p 6381 -a 123456
```

* 哨兵模式（通过哨兵连接）
```shell
redis-cli -h localhost -p 6385 -a 123456
```

* 集群模式
```shell
redis-cli -h localhost -p 7000 -a 123456 -c
```
