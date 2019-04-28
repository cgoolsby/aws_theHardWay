test=($(awk '{print $1}' IPs.txt))
echo $test
echo ${test[@]}
