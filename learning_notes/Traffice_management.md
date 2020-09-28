# Traffic Management

- Request Routing
- Fault Injection
- Traffic Shifting
- TCP Traffic Shifting
- Request Timeouts
- Circuit Breaking

# Request Routing
```
# istio gateway access
export GATEWAY_URL=$INGRESS_HOST
curl -s "http://${GATEWAY_URL}/productpage" | grep -o "<title>.*</title>"

```
# Fault Injection
```
# istio gateway access
export GATEWAY_URL=$INGRESS_HOST
curl -s "http://${GATEWAY_URL}/productpage" | grep -o "<title>.*</title>"

```
路由自动创建验证
```

 

```

负载均衡验证
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

超时/重试/故障注入
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

限流/熔断
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

应用监控指标
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

调用链追踪
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

蓝绿和灰度发布
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

流量镜像
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```

压力测试
```

curl -kv https://productpage-service.apps.cluster-2b7a.2b7a.sandbox1314.opentlc.com/productpage

```
