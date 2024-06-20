#!/bin/bash

echo "INSTALLED PACKAGES $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -f "sudo rpm -qa | grep steeleye-lk | sed 's/^/    /'" 

sleep 5
echo "CURRENT HIERARCHY $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -f "sudo /opt/LifeKeeper/bin/lcdstatus -q | sed 's/^/    /'"

sleep 5
echo "EQUIVALENCIES $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -f "sudo /opt/LifeKeeper/bin/eqv_list | sed 's/^/    /'"

exit 0
