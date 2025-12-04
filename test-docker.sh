#!/bin/bash

# 读取 .env 文件获取密码
if [ -f .env ]; then
    source .env
fi

REDIS_PASSWORD=${REDIS_PASSWORD:-123456}

echo "=========================================="
echo "测试 Redis 所有模式"
echo "=========================================="
echo ""

# 测试函数
test_redis() {
    local name=$1
    local host=$2
    local port=$3
    local password=$4
    
    echo "测试 $name (端口 $port)..."
    if docker exec $(docker ps -qf "name=$name") redis-cli -a "$password" ping 2>/dev/null | grep -q PONG; then
        echo "[OK] $name 连接成功"
        return 0
    else
        echo "[FAIL] $name 连接失败"
        return 1
    fi
}

# 1. 测试单机模式
echo "1. 单机模式 (Standalone)"
if docker ps | grep -q redis-standalone; then
    test_redis "redis-standalone" "localhost" "6380" "$REDIS_PASSWORD"
    STANDALONE_RESULT=$?
else
    echo "[FAIL] redis-standalone 容器未运行"
    STANDALONE_RESULT=1
fi
echo ""

# 2. 测试主从复制模式
echo "2. 主从复制模式 (Master-Slave)"
if docker ps | grep -q redis-replication-master; then
    test_redis "redis-replication-master" "localhost" "6381" "$REDIS_PASSWORD"
    MASTER_RESULT=$?
else
    echo "[FAIL] redis-replication-master 容器未运行"
    MASTER_RESULT=1
fi

if docker ps | grep -q redis-replication-slave; then
    test_redis "redis-replication-slave" "localhost" "6382" "$REDIS_PASSWORD"
    SLAVE_RESULT=$?
else
    echo "[FAIL] redis-replication-slave 容器未运行"
    SLAVE_RESULT=1
fi
echo ""

# 3. 测试哨兵模式
echo "3. 哨兵模式 (Sentinel)"
if docker ps | grep -q redis-sentinel-master; then
    test_redis "redis-sentinel-master" "localhost" "6383" "$REDIS_PASSWORD"
    SENTINEL_MASTER_RESULT=$?
else
    echo "[FAIL] redis-sentinel-master 容器未运行"
    SENTINEL_MASTER_RESULT=1
fi

if docker ps | grep -q redis-sentinel-slave; then
    test_redis "redis-sentinel-slave" "localhost" "6384" "$REDIS_PASSWORD"
    SENTINEL_SLAVE_RESULT=$?
else
    echo "[FAIL] redis-sentinel-slave 容器未运行"
    SENTINEL_SLAVE_RESULT=1
fi

if docker ps | grep -q redis-sentinel; then
    echo "测试 redis-sentinel (哨兵端口 6385)..."
    sentinel_container=$(docker ps -qf "name=^redis-sentinel$")
    if [ -n "$sentinel_container" ]; then
        if docker exec "$sentinel_container" redis-cli -p 26379 ping 2>/dev/null | grep -q PONG; then
            echo "[OK] redis-sentinel 连接成功"
            SENTINEL_RESULT=0
        else
            echo "[FAIL] redis-sentinel 连接失败"
            SENTINEL_RESULT=1
        fi
    else
        echo "[FAIL] redis-sentinel 容器未找到"
        SENTINEL_RESULT=1
    fi
else
    echo "[FAIL] redis-sentinel 容器未运行"
    SENTINEL_RESULT=1
fi
echo ""

# 4. 测试集群模式
echo "4. 集群模式 (Cluster)"
CLUSTER_RESULT=0
# 集群节点端口映射：1->7001, 2->7002, 3->7003, 4->7004, 5->7005, 6->7006
for i in 1 2 3 4 5 6; do
    container_name="redis-cluster-$i"
    port=$((7000 + i))
    if docker ps | grep -q "$container_name"; then
        test_redis "$container_name" "localhost" "$port" "$REDIS_PASSWORD"
        if [ $? -ne 0 ]; then
            CLUSTER_RESULT=1
        fi
    else
        echo "[FAIL] $container_name 容器未运行"
        CLUSTER_RESULT=1
    fi
done

# 检查集群初始化状态
echo "检查集群初始化状态..."
cluster_container=$(docker ps -qf "name=^redis-cluster-1$")
if [ -n "$cluster_container" ]; then
    CLUSTER_STATE=$(docker exec "$cluster_container" redis-cli -p 6379 -a "$REDIS_PASSWORD" CLUSTER INFO 2>/dev/null | grep "cluster_state" | cut -d: -f2 | tr -d '\r\n ' || echo "fail")
    if [ "$CLUSTER_STATE" = "ok" ]; then
        echo "[OK] Redis 集群已正确初始化 (cluster_state: ok)"
        # 检查集群节点数量
        CLUSTER_NODES=$(docker exec "$cluster_container" redis-cli -p 6379 -a "$REDIS_PASSWORD" CLUSTER NODES 2>/dev/null | wc -l | tr -d ' ')
        echo "    集群节点数: $CLUSTER_NODES"
    else
        echo "[FAIL] Redis 集群未正确初始化 (cluster_state: $CLUSTER_STATE)"
        CLUSTER_RESULT=1
    fi
else
    echo "[FAIL] 无法检查集群状态，redis-cluster-1 容器未找到"
    CLUSTER_RESULT=1
fi
echo ""

# 汇总结果
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
TOTAL_FAILED=0

if [ $STANDALONE_RESULT -eq 0 ]; then
    echo "[OK] 单机模式: 正常"
else
    echo "[FAIL] 单机模式: 失败"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

if [ $MASTER_RESULT -eq 0 ] && [ $SLAVE_RESULT -eq 0 ]; then
    echo "[OK] 主从复制模式: 正常"
else
    echo "[FAIL] 主从复制模式: 失败"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

if [ $SENTINEL_MASTER_RESULT -eq 0 ] && [ $SENTINEL_SLAVE_RESULT -eq 0 ] && [ $SENTINEL_RESULT -eq 0 ]; then
    echo "[OK] 哨兵模式: 正常"
else
    echo "[FAIL] 哨兵模式: 失败"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

if [ $CLUSTER_RESULT -eq 0 ]; then
    echo "[OK] 集群模式: 正常"
else
    echo "[FAIL] 集群模式: 失败"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

echo ""
if [ $TOTAL_FAILED -eq 0 ]; then
    echo "[OK] 所有模式测试通过！"
    exit 0
else
    echo "[FAIL] 有 $TOTAL_FAILED 种模式测试失败"
    exit 1
fi
