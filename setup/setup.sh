#!/usr/bin/env bash

set -e

minikube start \
	--vm-driver virtualbox \
	--cpus 2 \
	--memory 8192 \
	--disk-size 50g \
	--kubernetes-version=v1.15.5

# Helm 3
kubectl create namespace brigade
helm install brigade brigade/brigade --namespace brigade --values ~/k8s-snippets/kubecon/brigade-values.yaml

# Pre-pull images in case we don't have a network connection during the presentation
eval $(minikube docker-env)
docker pull krancour/brigade-worker:kubecon
docker pull alpine:3.8
docker pull krancour/brigade-worker:colors
docker pull lovethedrake/brigdrake-worker:v0.21.0
docker pull krancour/brigade-worker:drake

# Set up the projects

kubectl apply -f setup/resources
