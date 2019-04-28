#!/bin/bash
{
#readarray IPs < IPs.txt
IPs=($(awk '{print $1}' bothIPs.txt))
#readarray privateIPs < privateIPs.txt
privateIPs=($(awk '{print $2}' bothIPs.txt))
master=`echo ${privateIPs[@]}| awk '{for(i=1;i<=NF;i++)printf $(i)","}'`
echo $master

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
echo $master
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname="${IPs[0]},${master}kubernetes.default,127.0.0.1" -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
}
