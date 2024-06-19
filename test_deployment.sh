#!/bin/bash

echo "INSTALLED PACKAGES"
rpm -qa | grep steeleye-lk | sed 's/^/    /'

echo "CURRENT HIERARCHY"
lcdstatus -q | sed 's/^/    /'

echo "EQUIVALENCIES"
eqv_list | sed 's/^/    /'

exit 0;
