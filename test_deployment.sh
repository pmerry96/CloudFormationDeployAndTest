#!/bin/bash

echo "INSTALLED PACKAGES SPSL01"
echo "rpm -qa | grep steeleye-lk | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.0.100

echo "CURRENT HIERARCHY SPSL01"
echo "lcdstatus -q | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.0.100

echo "EQUIVALENCIES SPSL01"
echo "eqv_list | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.0.100

echo "INSTALLED PACKAGES SPSL02"
echo "rpm -qa | grep steeleye-lk | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.32.100

echo "CURRENT HIERARCHY SPSL02"
echo "lcdstatus -q | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.32.100

echo "EQUIVALENCIES SPSL02"
echo "eqv_list | sed 's/^/    /'" | ssh -i AUTOMATION.pem 10.0.32.100


exit 0;
