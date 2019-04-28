#!/bin/bash

set -e

#readarray IPs < IPs.txt
IPs=($(awk '{print $1}' bothIPs.txt))
#readarray privateIPs < privateIPs.txt
privateIPs=($(awk '{print $2}' bothIPs.txt))
length=`echo ${#IPs[@]}`
master=${IPs[0]}
pem=jello.pem
for inst in `seq 0 5`; do
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	scp -oStrictHostKeyChecking=no -i $pem bothIPs.txt "ubuntu@$i:"
done
####installing Client Tools - cfssl and cfssljson
#curl -o cfssl https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
#curl -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
#chmod +x cfssl cfssljson
#sudo mv cfssl cfssljson /usr/local/bin/
####install Primary key infrastructure
script="PKI.sh"
for i in ${IPs[@]}; do
       	echo $i;echo; echo; echo "scp: "
	scp -oStrictHostKeyChecking=no -i $pem $script ubuntu@$i:; echo "ssh:"
       	ssh -oStrictHostKeyChecking=no -i $pem ubuntu@$i bash $script;echo; echo
done

####install kubectl on control machine.  Currently linux
#curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl; chmod +x kubectl; sudo mv kubectl /usr/local/bin/; kubectl version --client
curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/darwin/amd64/kubectl; chmod +x kubectl; sudo mv kubectl /usr/local/bin/; kubectl version --client

#SSH key access?
#Provisioning a CA and generating TLS Certificates

####CA
bash CA.sh
####Client and Server Certificates
bash adminCA.sh
bash clientCA.sh
bash kubeController.sh
bash kubeProxy.sh
bash kubeScheduler.sh
bash kubeFinal.sh
bash serviceAccounts.sh
####Distribute client and server certificates
####copy CA to worker instances
for inst in `seq 3 5`; do # 3 4 5
	ins=$(($inst-3))
	instance="worker-$ins"
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	echo "ubuntu@$i:"
	scp -oStrictHostKeyChecking=no -i $pem ca.pem $instance-key.pem $instance.pem "ubuntu@$i:"
done
####Copy CA to controller instances
for inst in `seq 0 2`; do # 0 1 2
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	scp -oStrictHostKeyChecking=no -i $pem ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem "ubuntu@$i:"
done

####Generate Kubernetes Config files for authentication
bash kubectlConfig.sh
bash kube-proxy.sh
bash kube-controller-manager.sh
bash kube-scheduler.sh
bash kube-admin.sh
####copy kubelete and kube-proxy to workers
for inst in `seq 3 5`; do # 3 4 5
	ins=$(($inst-3))
	instance="worker-$ins"
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	echo "ubuntu@$i"
	scp -oStrictHostKeyChecking=no -i $pem ${instance}.kubeconfig kube-proxy.kubeconfig "ubuntu@$i:"
done
####copy kube-controller-manager and kube-scheduler to master node
for inst in `seq 0 2`; do # 0 1 2
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	scp -oStrictHostKeyChecking=no -i $pem admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig "ubuntu@$i:"
done

####generate data encryption config and key
bash encryption.sh
for inst in `seq 0 2`; do # 0 1 2
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	scp -oStrictHostKeyChecking=no -i $pem encryption-config.yaml "ubuntu@$i:"
done


####Bootstrap the ETCD Server
script=etcdBootstrap.sh
for inst in `seq 0 2`; do # 0 1 2
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
       	echo $i;echo; echo; echo "scp: "
	scp -oStrictHostKeyChecking=no -i $pem $script ubuntu@$i:
       	echo "ssh:"
       	ssh -oStrictHostKeyChecking=no -i $pem ubuntu@$i bash $script;echo; echo;
done


script=bootstrapControlPlane.sh
for inst in `seq 0 2`; do # 0 1 2
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	echo $i;echo; echo; echo "scp: "
	scp -oStrictHostKeyChecking=no -i $pem $script ubuntu@$i:
       	echo "ssh:"
	ssh -oStrictHostKeyChecking=no -i $pem ubuntu@$i bash $script;echo; echo;
done
curl --cacert ca.pem https://${IPs[0]}:6443/version

#bootstrap workers
script=bootstrapWorkers.sh
for inst in `seq 3 5`; do # 3 4 5
	ins=$(($inst-3))
	instance="worker-$ins"
	i=`echo ${IPs[$inst]} | awk '{$1=$1;print}'`
	scp -oStrictHostKeyChecking=no -i $pem $script ubuntu@$i:
       	echo "ssh:"
	ssh -oStrictHostKeyChecking=no -i $pem ubuntu@$i bash $script;echo; echo;
	ssh -oStrictHostKeyChecking=no -i $pem ubuntu@$i 'sudo ln -s /run/resolvconf/ /run/systemd/resolve';echo; echo;
done
sed -i .bak "s/127.0.0.1/${IPs[0]}/g" admin.kubeconfig
kubectl get nodes --kubeconfig admin.kubeconfig
kubectl create -f flannel.yaml --kubeconfig admin.kubeconfig
kubectl create deployment nginx --image=nginx --kubeconfig admin.kubeconfig
