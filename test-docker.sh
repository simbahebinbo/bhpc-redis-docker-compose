#!/bin/bash

# 测试单机模式 Redis (端口 6380)
echo "测试单机模式 Redis (端口 6380)"
echo "输入: auth 123456"
redis-cli -h 127.0.0.1 -p 6380 -a 123456
