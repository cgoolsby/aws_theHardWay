#!/bin/bash
#readarray IPs < IPs.txt
IPs=($(awk '{print $1}' bothIPs.txt))
#readarray privateIPs < privateIPs.txt
privateIPs=($(awk '{print $2}' bothIPs.txt))
length=`echo ${#IPs[@]}`
master=`echo ${IPs[0]}|awk '{$1=$1;print}'`
for inst in `seq 3 5`; do
	i=$(($inst-3))
	instance="worker-$i"
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${master}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
