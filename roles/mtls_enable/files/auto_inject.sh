#!/bin/sh #

if [ -z $1 ] || [ -z $2 ];then
   echo "Please input the right parameters!"
   exit 1
fi

oc -n $2 patch --type='json' smmr default -p '[{"op": "add", "path": "/spec/members", "value":["'"bookinfo"'"]}]'

for i in $(kubectl get deployments -o jsonpath='{range.items[*]}{.metadata.name}{"\n"}{end}' -n $1);
do 
  echo $i; oc patch deployment $i -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject": "true"}}}}}'; 

done