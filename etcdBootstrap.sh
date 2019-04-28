#!/bin/bash

echo "*******BEGIN ETCD********"

wget -q --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"

{
  tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
  sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
}

{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}

#readarray IPs < IPs.txt
IPs=($(awk '{print $1}' bothIPs.txt))
#readarray privateIPs < privateIPs.txt
privateIPs=($(awk '{print $2}' bothIPs.txt))
INTERNAL_IP=`ifconfig | grep "inet addr:10." | awk 'BEGIN{FS=":"}; {print $2}' | awk '{print $1}'`
INTERNAL_IP0=`echo ${privateIPs[0]} | awk '{$1=$1;print}'`
INTERNAL_IP1=`echo ${privateIPs[1]} | awk '{$1=$1;print}'`
INTERNAL_IP2=`echo ${privateIPs[2]} | awk '{$1=$1;print}'`
if [ "$INTERNAL_IP0" = "$INTERNAL_IP" ]; then
  ETCD_NAME="controller-0"
fi
if [ "$INTERNAL_IP1" = "$INTERNAL_IP" ]; then
  ETCD_NAME="controller-1"
fi
if [ "$INTERNAL_IP2" = "$INTERNAL_IP" ]; then
  ETCD_NAME="controller-2"
fi

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://${INTERNAL_IP0}:2380,controller-1=https://${INTERNAL_IP1}:2380,controller-2=https://${INTERNAL_IP2}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}

#sudo ETCDCTL_API=3 etcdctl member list \
#  --endpoints=https://127.0.0.1:2379 \
#  --cacert=/etc/etcd/ca.pem \
#  --cert=/etc/etcd/kubernetes.pem \
#  --key=/etc/etcd/kubernetes-key.pem

echo $INTERNAL_IP
echo "*******END ETCD********"
#curl -L http://127.0.0.1:2379/health

