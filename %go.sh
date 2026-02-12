
if [ -x /usr/bin/go ];then
	export GOPATH=$(go env GOPATH)
	export PATH=$PATH:$GOPATH/bin
fi

