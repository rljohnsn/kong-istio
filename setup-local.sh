#!/bin/sh
set -e
# Apache Software License 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Description:
# 
# Convenience script to prepare a mac to run minikube. Additionally
# setting up:
#  * istio
#  * kong ingress api gateway
#  * kiali - istio dashboard
#  * prometheus
#  * grafana
#

HELM_VERSION=${HELM_VERSION:=helm} # EXPORT HELM_VERSION=helm@2 for Helm 2
ISTIO_VERSION=${ISTIO_VERSION:=1.14.1}
ISTIO_HOME=./istio-${ISTIO_VERSION}
K8S_VERSION=${K8S_VERSION:=1.23.3}
MINIK_CPU=${MINIK_CPU:=6}
MINIK_MEM=${MINIK_MEM:=12g}

# Installing dependencies
brew list > ./.brew-list.txt
[ "$(grep -ci figlet ./.brew-list.txt)"         -eq 0 ] && brew install figlet
[ "$(grep -ci lolcat ./.brew-list.txt)"         -eq 0 ] && brew install lolcat
[ "$(grep -ci minikube ./.brew-list.txt)"       -eq 0 ] && brew install minikube
[ "$(grep -ci helm ./.brew-list.txt)"           -eq 0 ] && brew install $HELM_VERSION
[ "$(grep -ci kubernetes-cli ./.brew-list.txt)" -eq 0 ] && brew install kubernetes-cli

# Configure Minikube and Kubectl
figlet minikube | lolcat
# Don't blast someones exiting use of .kube/minikube
[ -f ~/.kube/minikube ] && mv ~/.kube/minikube ~/.kube/minikube.bak
cat /dev/null > ~/.kube/minikube
chmod 700 ~/.kube/minikube

# Customize minikube profile
minikube config set cpus $MINIK_CPU
minikube config set memory $MINIK_MEM
minikube config set profile $K8S_VERSION

# Ensure we are up todate and start if not started
(minikube update-check && minikube status) || minikube start --kubernetes-version=$K8S_VERSION -p $K8S_VERSION

minikube profile list 
export KUBECONFIG=~/.kube/minikube
minikube update-context

figlet kubectl | lolcat
minikube kubectl version
minikube kubectl cluster-info
minikube kubectl get nodes

# Helm Repositories
figlet Helm | lolcat
helm version
echo
helm repo list > ./.helm-repo-list.txt
[ "$(grep -ci appscode ./.helm-repo-list.txt)"    -eq 0 ] && helm repo add appscode https://charts.appscode.com/stable/
[ "$(grep -ci bitnami ./.helm-repo-list.txt)"     -eq 0 ] && helm repo add bitnami https://charts.bitnami.com/bitnami
[ "$(grep -ci chartmuseum ./.helm-repo-list.txt)" -eq 0 ] && helm repo add chartmuseum https://chartmuseum.es.8x8.com
[ "$(grep -ci fluent ./.helm-repo-list.txt)"      -eq 0 ] && helm repo add fluent https://fluent.github.io/helm-charts
[ "$(grep -ci grafana ./.helm-repo-list.txt)"     -eq 0 ] && helm repo add grafana https://grafana.github.io/helm-charts
[ "$(grep -ci hashicorp ./.helm-repo-list.txt)"   -eq 0 ] && helm repo add hashicorp https://helm.releases.hashicorp.com
[ "$(grep -ci helm2 ./.helm-repo-list.txt)"       -eq 0 ] && helm repo add helm2 https://charts.helm.sh/stable
[ "$(grep -ci minio ./.helm-repo-list.txt)"       -eq 0 ] && helm repo add minio https://helm.min.io/
[ "$(grep -ci kong ./.helm-repo-list.txt)"        -eq 0 ] && helm repo add kong https://charts.konghq.com
# helm repo update
helm repo list
# If we are working with helm@2 then initialize and install Tiller
[ "$(echo $HELM_VERSION | grep -ci 2)" -gt 0 ] && helm init --upgrade --wait --history-max 10

echo 
helm list -ra

figlet istio | lolcat
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} TARGET_ARCH=`uname -m` sh -
pushd .
cd ${ISTIO_HOME}
export PATH=$PWD/bin:$PATH
popd

# Check if istio will install, if check or install fails exit.
(istioctl x precheck) && istioctl install --set profile=demo -y || exit 1
minikube kubectl -- label --overwrite namespace default istio-injection=enabled 

figlet prometheus | lolcat
minikube kubectl -- apply -f ${ISTIO_HOME}/samples/addons/prometheus.yaml
figlet grafana | lolcat
minikube kubectl -- apply -f ${ISTIO_HOME}/samples/addons/grafana.yaml
figlet kiali | lolcat
minikube kubectl -- apply -f ${ISTIO_HOME}/samples/addons/kiali.yaml

figlet kong | lolcat
[ "$(minikube kubectl -- get namespaces | grep -ci kong-istio)" -eq 0 ] && minikube kubectl -- create namespace kong-istio
minikube kubectl -- label --overwrite namespace kong-istio istio-injection=enabled 
[ "$(helm list -A | grep -ci kong-istio)" -eq 0 ] && helm install -n kong-istio kong-istio kong/kong

figlet istio-sample | lolcat
[ "$(minikube kubectl -- get namespaces | grep -ci bookinfo)" -eq 0 ] && minikube kubectl -- create namespace bookinfo
minikube kubectl -- label --overwrite namespace bookinfo istio-injection=enabled
minikube kubectl -- -n bookinfo apply -f ${ISTIO_HOME}/samples/bookinfo/platform/kube/bookinfo.yaml
minikube kubectl -- apply -f bookinfo-ratelimiter.yaml
minikube kubectl -- apply -f bookinfo-ingress.yaml

echo
echo "Execute minikube tunnel in another terminal and leave it running to connect to services of type LoadBalancer"

figlet profit | lolcat
sleep 4
# Launch the dashboard
minikube dashboard

