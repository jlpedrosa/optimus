#!/bin/bash

NAMESPACE="jlpedrosa"
#this step is not necesary fro groupon
#kubectl create namespace "$NAMESPACE"
kubectl config set-context --current --namespace="$NAMESPACE"

helm install -f mysql/helmparams.yaml poc-mysql stable/mysql
helm install -f nifi/helmvalues.yaml poc-nifi cetic/nifi

#Log into the pod:
kubectl exec -i -t poc-nifi-0 server -- /bin/bash

#Downlad mysql driver
cd /opt/nifi/
mkdir extra
cd extra/
wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.22/mysql-connector-java-8.0.22.jar

#UI
create SQLProcessor with a new connection pool (using /opt/nifi/extra as path)
Create a processor to write to teradata
Connecto bth with success relationship.



## Interesting commands
# kubectl run -i --tty ubuntu --image=ubuntu:20.04 --restart=Never -- bash -il
# helm repo add stable https://charts.helm.sh/stable
# helm repo add cetic https://cetic.github.io/helm-charts
# helm repo update

# helm uninstall poc-mysql
# kubectl logs poc-nifi-0 -f

## Links
#external-dns (update dns entries for external dns servers)
#https://github.com/kubernetes-sigs/external-dns
#https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
#https://github.com/Orange-OpenSource/nifikop
