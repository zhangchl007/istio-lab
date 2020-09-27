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
