#!/bin/bash

echo "INSTALLED PACKAGES SPSL01"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.0.100 -f "sudo rpm -qa | grep steeleye-lk | sed 's/^/    /'" 

echo "CURRENT HIERARCHY SPSL01"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.0.100 -f "sudo /opt/LifeKeeper/bin/lcdstatus -q | sed 's/^/    /'"

echo "EQUIVALENCIES SPSL01"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.0.100 -f "sudo /opt/LifeKeeper/bin/eqv_list | sed 's/^/    /'"

echo "INSTALLED PACKAGES SPSL02"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.32.100 -f "sudo rpm -qa | grep steeleye-lk | sed 's/^/    /'"

echo "CURRENT HIERARCHY SPSL02"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.32.100 -f "sudo /opt/LifeKeeper/bin/lcdstatus -q | sed 's/^/    /'"

echo "EQUIVALENCIES SPSL02"
ssh -o "StrictHostKeyChecking no" -i $1 10.0.32.100 -f "sudo /opt/LifeKeeper/bin/eqv_list | sed 's/^/    /'"

exit 0
