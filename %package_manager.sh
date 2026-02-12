if [ -e /usr/bin/apt-get ];then
   export IST=apt-get
   export PM=apt-get
   export DVP=dev
fi
if [ -e /usr/bin/yum ];then
   export IST=yum
   export PM=yum
   export DVP=devel
fi
if [ -e /usr/bin/dnf ];then
   export IST=dnf
   export PM=dnf
   export DVP=devel
fi

