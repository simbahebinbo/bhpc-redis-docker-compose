### 配置说明

然后根据需要修改 `.env` 文件中的  `REDIS_PASSWORD`。

### Redis 部署模式说明

本项目支持 4 种 Redis 部署模式：

1. **单机模式 (Standalone)**
   - 端口: `6380`
   - 容器: `redis-standalone`

2. **主从复制模式 (Master-Slave Replication)**
   - 主节点端口: `6381` (容器: `redis-replication-master`)
   - 从节点端口: `6382` (容器: `redis-replication-slave`)

3. **哨兵模式 (Sentinel)**
   - 主节点端口: `6383` (容器: `redis-sentinel-master`)
   - 从节点端口: `6384` (容器: `redis-sentinel-slave`)
   - 哨兵端口: `6385` (容器: `redis-sentinel`)
   - 连接方式: 通过哨兵端口 `6385` 连接

4. **集群模式 (Cluster)**
   - 节点端口: `7001-7006` (容器: `redis-cluster` )
   - 集群总线端口: `17001-17006`


### 使用方式

* 启动所有模式

```shell
$ ./start-docker.sh
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
redis-cli -h localhost -p 7001 -c
```
