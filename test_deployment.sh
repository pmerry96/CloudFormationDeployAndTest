#!/bin/bash

echo "INSTALLED PACKAGES $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -q "sudo rpm -qa | grep steeleye-lk | sed 's/^/    /'" 

echo ""
echo "CURRENT HIERARCHY $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -q "sudo /opt/LifeKeeper/bin/lcdstatus -q | sed 's/^/    /'"

echo ""
echo "EQUIVALENCIES $2"
ssh -o "StrictHostKeyChecking no" -i $1 ec2-user@$2 -q "sudo /opt/LifeKeeper/bin/eqv_list | sed 's/^/    /'"

exit 0
