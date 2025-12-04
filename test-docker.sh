#!/bin/bash

REDIS_PASSWORD=123456

echo "=========================================="
echo "测试 Redis 所有模式"
echo "=========================================="
echo ""

# 测试函数 - 使用 docker exec
test_redis() {
    local name=$1
    local port=$2
    local password=$3
    
    echo "测试 $name (端口 $port)..."
    
    local container_id=$(docker ps -qf "name=$name")
    if [ -z "$container_id" ]; then
        echo "[FAIL] $name 容器未找到"
        return 1
    fi
    
    if [ -z "$password" ] || [ "$password" = "" ]; then
        # 无密码连接（grokzen 默认）
        if docker exec "$container_id" redis-cli -h localhost ping 2>/dev/null | grep -q PONG; then
            echo "[OK] $name 连接成功"
            return 0
        fi
    else
        # 有密码连接（bitnami）
        if docker exec "$container_id" redis-cli -h localhost -a "$password" ping 2>/dev/null | grep -q PONG; then
            echo "[OK] $name 连接成功"
            return 0
        fi
    fi
    echo "[FAIL] $name 连接失败"
    return 1
}

# 1. 测试单机模式
echo "1. 单机模式 (Standalone)"
if docker ps | grep -q redis-standalone; then
    test_redis "redis-standalone" "6380" "$REDIS_PASSWORD"
    STANDALONE_RESULT=$?
else
    echo "[FAIL] redis-standalone 容器未运行"
    STANDALONE_RESULT=1
fi
echo ""

# 2. 测试主从复制模式
echo "2. 主从复制模式 (Master-Slave)"
if docker ps | grep -q redis-replication-master; then
    test_redis "redis-replication-master" "6381" "$REDIS_PASSWORD"
    MASTER_RESULT=$?
else
    echo "[FAIL] redis-replication-master 容器未运行"
    MASTER_RESULT=1
fi

if docker ps | grep -q redis-replication-slave; then
    test_redis "redis-replication-slave" "6382" "$REDIS_PASSWORD"
    SLAVE_RESULT=$?
else
    echo "[FAIL] redis-replication-slave 容器未运行"
    SLAVE_RESULT=1
fi
echo ""

# 3. 测试哨兵模式
echo "3. 哨兵模式 (Sentinel)"
if docker ps | grep -q redis-sentinel-master; then
    test_redis "redis-sentinel-master" "6383" "$REDIS_PASSWORD"
    SENTINEL_MASTER_RESULT=$?
else
    echo "[FAIL] redis-sentinel-master 容器未运行"
    SENTINEL_MASTER_RESULT=1
fi

if docker ps | grep -q redis-sentinel-slave; then
    test_redis "redis-sentinel-slave" "6384" "$REDIS_PASSWORD"
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
cluster_container=$(docker ps -qf "name=^redis-cluster$")
if [ -n "$cluster_container" ]; then
    # grokzen/redis-cluster: 单个容器，内部运行 6 个节点
    echo "检测到 grokzen/redis-cluster（单容器模式）"
    # grokzen 默认无密码，测试连接（容器内端口 7000-7005）
    for i in 0 1 2 3 4 5; do
        container_port=$((7000 + i))
        echo "测试 redis-cluster 节点 $((i+1)) (容器内端口 $container_port)..."
        if docker exec "$cluster_container" redis-cli -p $container_port ping 2>/dev/null | grep -q PONG; then
            echo "[OK] redis-cluster 节点 $((i+1)) 连接成功"
        else
            echo "[FAIL] redis-cluster 节点 $((i+1)) 连接失败"
            CLUSTER_RESULT=1
        fi
    done
    
    # 检查集群初始化状态
    echo "检查集群初始化状态..."
    CLUSTER_STATE=$(docker exec "$cluster_container" redis-cli -p 7000 CLUSTER INFO 2>/dev/null | grep "cluster_state" | cut -d: -f2 | tr -d '\r\n ' || echo "fail")
    if [ "$CLUSTER_STATE" = "ok" ]; then
        echo "[OK] Redis 集群已正确初始化 (cluster_state: ok)"
        CLUSTER_NODES=$(docker exec "$cluster_container" redis-cli -p 7000 CLUSTER NODES 2>/dev/null | wc -l | tr -d ' ')
        echo "    集群节点数: $CLUSTER_NODES"
    else
        echo "[FAIL] Redis 集群未正确初始化 (cluster_state: $CLUSTER_STATE)"
        CLUSTER_RESULT=1
    fi
else
    echo "[FAIL] 未找到 redis-cluster 容器"
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
