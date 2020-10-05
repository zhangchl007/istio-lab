# Authentication and Authorization
istio1.4 AuthorizationPolicy only supports “ALLOW” action. This means that if multiple authorization policies apply to the same workload, the effect is additive.
The v1beta1 policy is not backward compatible and requires a one time conversion. A tool is provided to automate this process. The previous configuration resources ClusterRbacConfig, ServiceRole, and ServiceRoleBinding will not be supported from Istio 1.6 onwards.

 istio1.7+ is better
- authentication policy
- mutual TLS authentication
- sso integretion

# Authorization

```
# case setup
oc adm policy add-scc-to-user anyuid -z httpbin
kubectl create ns foo
kubectl apply -f httpbin.yaml -n foo
kubectl apply -f sleep.yaml -n foo

oc adm policy add-scc-to-user anyuid -z httpbin
kubectl create ns bar
kubectl apply -f httpbin.yaml -n bar
kubectl apply -f sleep.yaml -n bar

oc adm policy add-scc-to-user anyuid -z httpbin
kubectl create ns legacy
kubectl apply -f httpbin.yaml -n legacy
kubectl apply -f sleep.yaml -n legacy

#verify setup by sending an HTTP request with curl from any sleep pod in the namespace foo, bar or legacy

for i in foo bar legacy;
do 
kubectl exec $(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name}) -c sleep -n bar -- curl http://httpbin.${i}:8000/ip -s -o /dev/null -w "%{http_code}\n"
done

for from in "foo" "bar" "legacy"; do for to in "foo" "bar" "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl "http://httpbin.${to}:8000/ip" -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done

#  verify mesh authentication policy 
kubectl get policies.authentication.istio.io --all-namespaces
oc get smmr --all-namespaces

# review crd for openshift 4.5 
oc get crd |grep -i  istio
adapters.config.istio.io                                    2020-08-11T11:20:03Z
attributemanifests.config.istio.io                          2020-08-11T11:20:04Z
authorizationpolicies.security.istio.io                     2020-08-11T11:20:04Z
destinationrules.networking.istio.io                        2020-08-11T11:20:04Z
envoyfilters.networking.istio.io                            2020-08-11T11:20:04Z
gateways.networking.istio.io                                2020-08-11T11:20:04Z
handlers.config.istio.io                                    2020-08-11T11:20:04Z
httpapispecbindings.config.istio.io                         2020-08-11T11:20:04Z
httpapispecs.config.istio.io                                2020-08-11T11:20:04Z
instances.config.istio.io                                   2020-08-11T11:20:04Z
policies.authentication.istio.io                            2020-08-11T11:20:04Z
quotaspecbindings.config.istio.io                           2020-08-11T11:20:03Z
quotaspecs.config.istio.io                                  2020-08-11T11:20:03Z
rbacconfigs.rbac.istio.io                                   2020-08-11T11:20:03Z
rules.config.istio.io                                       2020-08-11T11:20:03Z
serviceentries.networking.istio.io                          2020-08-11T11:20:04Z
servicerolebindings.rbac.istio.io                           2020-08-11T11:20:03Z
serviceroles.rbac.istio.io                                  2020-08-11T11:20:04Z
sidecars.networking.istio.io                                2020-08-11T11:20:04Z
templates.config.istio.io                                   2020-08-11T11:20:04Z
virtualservices.networking.istio.io                         2020-08-11T11:20:04Z

# verify that there are no destination rules
kubectl get destinationrules.networking.istio.io --all-namespaces -o yaml | grep "host:"

# deployment inject 

oc patch deployment httpbin -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n foo
oc patch deployment httpbin -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n bar
oc patch deployment httpbin -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n legacy

oc patch deployment sleep -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n foo
oc patch deployment sleep -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n bar
oc patch deployment sleep -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}' -n legacy

# enable mtls 
for i in foo bar legacy;do oc apply -f httpbin-mtls.yaml -n $i;done
for i in foo bar legacy;do oc apply -f sleep-mtls.yaml -n $i;done

#  add a destination rule to overwrite the TLS setting for httpbin.legacy,this item can't overwrite the policy 
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
 name: "httpbin-legacy"
 namespace: "legacy"
spec:
 host: "httpbin.legacy.svc.cluster.local"
 trafficPolicy:
   tls:
     mode: DISABLE
EOF
# delete httpbin-mtls policy 
oc delete policy httpbin-mtls  -n legacy
for from in "foo" "bar"; do for to in "legacy"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl "http://httpbin.${to}:8000/ip" -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done

# Request from Istio services to Kubernetes API server
TOKEN=$(kubectl describe secret $(kubectl get secrets | grep default-token | cut -f1 -d ' ' | head -1) | grep -E '^token' | cut -f2 -d':' | tr -d ' \t')
kubectl exec $(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name}) -c sleep -n foo -- curl https://kubernetes.default/api --header "Authorization: Bearer $TOKEN" --insecure -s -o /dev/null -w "%{http_code}\n"

# Namespace-wide policy

kubectl apply -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "default"
  namespace: "legacy"
spec:
  peers:
  - mtls: {}
EOF

# Add corresponding destination rule

 kubectl apply -f - <<EOF
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "default"
  namespace: "legacy"
spec:
  host: "*.legacy.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

# Service-specific policy

 kubectl apply -f - <<EOF
apiVersion: authentication.istio.io/v1alpha1
kind: Policy
metadata:
  name: httpbin-mtls
spec:
  peers:
  - mtls:
      mode: STRICT
  targets:
  - name: httpbin
EOF

# Policy precedence

kubectl apply -n legacy -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "overwrite-example"
spec:
  targets:
  - name: httpbin
EOF

# destination rule
kubectl apply -n legacy -f - <<EOF
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "overwrite-example"
spec:
  host: httpbin.legacy.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
EOF

# confirming service-specific policy overrides the namespace-wide policy.

kubectl exec $(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name}) -c sleep -n foo  -- curl http://httpbin.legacy:8000/ip -s -o /dev/null -w "%{http_code}\n"

```
# End-user authentication

```
# create ingress gateway
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
  namespace: legacy
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF
# create virtual service

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
  namespace: legacy
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        port:
          number: 8000
        host: httpbin.legacy.svc.cluster.local
EOF
# k8s native export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# Get ingress route
export INGRESS_ROUTE=$(oc get route -n istio-system istio-ingressgateway -o jsonpath='{.items[*]}{.spec.host}')
curl $INGRESS_ROUTE/headers -s -o /dev/null -w "%{http_code}\n"

# Enable end-user JWT for httpbin.foo

 kubectl apply -n legacy -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
spec:
  targets:
  - name: httpbin
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/jwks.json"
  principalBinding: USE_ORIGIN
EOF

$ curl $INGRESS_ROUTE/headers -s -o /dev/null -w "%{http_code}\n"
401

# Attaching the valid token 

export INGRESS_ROUTE=$(oc get route -n istio-system istio-ingressgateway -o jsonpath='{.items[*]}{.spec.host}')
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s)
curl --header "Authorization: Bearer $TOKEN" $INGRESS_ROUTE/headers -s -o /dev/null -w "%{http_code}\n"

# use the script gen-jwt.py to generate new tokens to test with different issuer, audiences, expiry date

wget https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/gen-jwt.py
chmod +x gen-jwt.py
wget https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/key.pem

# perform a test

export INGRESS_ROUTE=$(oc get route -n istio-system istio-ingressgateway -o jsonpath='{.items[*]}{.spec.host}')
TOKEN=$(./gen-jwt.py ./key.pem --expire 5)
for i in `seq 1 10`; do curl --header "Authorization: Bearer $TOKEN" $INGRESS_ROUTE/headers -s -o /dev/null -w "%{http_code}\n"; sleep 1; done

# Disable End-user authentication for specific paths
 kubectl apply -n legacy -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
spec:
  targets:
  - name: httpbin
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/jwks.json"
      trigger_rules:
      - excluded_paths:
        - exact: /user-agent
  principalBinding: USE_ORIGIN
EOF

curl $INGRESS_ROUTE/user-agent -s -o /dev/null -w "%{http_code}\n"
curl $INGRESS_ROUTE/headers -s -o /dev/null -w "%{http_code}\n"


# Enable End-user authentication for specific paths

 kubectl apply -n legacy -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
spec:
  targets:
  - name: httpbin
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/jwks.json"
      trigger_rules:
      - included_paths:
        - exact: /ip
  principalBinding: USE_ORIGIN
EOF

curl $INGRESS_ROUTE/user-agent -s -o /dev/null -w "%{http_code}\n"
curl $INGRESS_ROUTE/ip -s -o /dev/null -w "%{http_code}\n"

# Confirm it’s allowed to access the path /ip with a valid JWT token

TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s)
curl --header "Authorization: Bearer $TOKEN" $INGRESS_ROUTE/ip -s -o /dev/null -w "%{http_code}\n"

# End-user authentication with mutual TLS

 kubectl apply -n legacy -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "jwt-example"
spec:
  targets:
  - name: httpbin
  peers:
  - mtls: {}
  origins:
  - jwt:
      issuer: "testing@secure.istio.io"
      jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/jwks.json"
  principalBinding: USE_ORIGIN
EOF

# add a destination rule

kubectl apply -f - <<EOF
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "httpbin"
  namespace: "legacy"
spec:
  host: "httpbin.legacy.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s)
kubectl exec $(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name}) -c sleep -n foo -- curl http://httpbin.legacy:8000/ip -s -o /dev/null -w "%{http_code}\n" --header "Authorization: Bearer $TOKEN"

# Cleanup part 3

kubectl -n legacy delete policy jwt-example
kubectl -n legacy delete destinationrule httpbin
kubectl delete ns foo bar legacy

```
# Keycloak/jwt integrition 

```
#  


```

# Mirroring

```
# Creating a default routing policy
1. Create a default route rule to route all traffic to v1 of the service:

2. Send some traffic to the service:
export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl exec "${SLEEP_POD}" -c sleep -- curl -s http://httpbin:8000/headers 

3. Check the logs for v1 and v2 of the httpbin pods. You should see access log entries for v1 and none for v2:
 export V1_POD=$(kubectl get pod -l app=httpbin,version=v1 -o jsonpath={.items..metadata.name})
 kubectl logs "$V1_POD" -c httpbin

 export V2_POD=$(kubectl get pod -l app=httpbin,version=v2 -o jsonpath={.items..metadata.name})
 kubectl logs "$V2_POD" -c httpbin

# Mirroring traffic to v2
1. Change the route rule to mirror traffic to v2:

2. Send in traffic:

 kubectl exec "${SLEEP_POD}" -c sleep -- curl -s http://httpbin:8000/headers
 kubectl logs "$V1_POD" -c httpbin
 kubectl logs "$V2_POD" -c httpbin



```