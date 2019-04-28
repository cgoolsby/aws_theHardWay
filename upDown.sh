export PATH=$HOME/go/bin:$PATH
rm bothIPs.txt
terraform destroy -var key_name=jello -auto-approve; terraform apply -auto-approve -var key_name=jello; ./main.sh

