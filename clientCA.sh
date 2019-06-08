#!/bin/bash
#readarray IPs < IPs.txt
IPs=($(awk '{print $1}' bothIPs.txt))
#readarray privateIPs < privateIPs.txt
internal=($(awk '{print $2}' bothIPs.txt))
length=`echo ${#IPs[@]}`

for inst in `seq 3 5`; do
	i=$(($inst-3))
	instance="worker-$i"
#for instance in worker-0 worker-1 worker-2; do
	cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP="${IPs[3]},${IPs[4]},${IPs[5]}"
#EXTERNAL_IP=${IPs[$inst]}

INTERNAL_IP="${internal[3]},${internal[4]},${internal[5]}"
#INTERNAL_IP=${internal[$inst]}

echo $inst, $instance
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname="${instance},${EXTERNAL_IP},${INTERNAL_IP},10.32.0.1" -profile=kubernetes ${instance}-csr.json | cfssljson -bare ${instance}

done
