rm_all(){
	if [ ! -e "$1" ];then
		err "'$1' does not exist."
		return 1
	fi
	local d
	local dlen
	local ln
	local blockDevs=()
	local f
	local l
	local NoBlockDevDir
	if [ -n "`ls -A /dev/block`" ];then
		for f in /dev/block/*;do
			l="`readlink -f $f`"
			if [ "${l:0:5}" = "/dev/" ];then
				blockDevs+=("${l#/dev/}")
			fi
		done 2> /dev/null
	elif [ -n "$IN_WSL" ]; then
		NoBlockDevDir=1
	fi 
	d=$($__sudo__ realpath $1)
	if [ "$d" = "/" ];then
		err "cannot use rm_all to '/'"
		return 1
	fi
	dlen=${#d}
	dlen=$((dlen + 1))
	cat /proc/mounts|awk '{print $2}'| sed -n '1!G;h;$p' |while read ln;do
		if [ "${ln:0:$dlen}" = "$d/" ];then
			if ! $__sudo__ umount $VERBOSE_OPT $ln;then
				err "cannot unmount '$ln'"
				return 1
			fi
		fi
	done
	local lnLen1
	local fsType
	local b
	local doRm
	local dln

	cat /proc/mounts|awk '{print $2 " " $1}'| sed -n '1!G;h;$p' |while read ln;do
		dln="`echo $ln | awk '{print $1}'`"
		lnLen1=$((${#dln} + 1))
		if [ "${d:0:$lnLen1}" = "$dln/" -o "$d" = "$dln" -o "$dln" = "/" ];then
			fsType="`echo $ln | awk '{print $2}'`"
			if [ "$fsType" = "overlay" ];then
				doRm=1
			else
				if [ "${fsType:0:5}" = "/dev/" ];then
					fsType=`readlink -f $fsType`
					for b in ${blockDevs[@]}; do
						if [ "$b" = "${fsType#/dev/}" ];then
							doRm=1
							break
						fi
					done
					if [ -n "$NoBlockDevDir" ]; then
						if [ "${fsType:0:7}" = "/dev/sd" ];then
							doRm=1
						fi
					fi
				elif [ -n "$NoBlockDevDir" ] && [[ ${fsType:0:2} =~ [A-Z]: ]];then
					doRm=1
				fi
			fi
			if [ -n "$doRm" ];then
				$__sudo__ /bin/rm $VERBOSE_OPT --one-file-system -rf "$d"
			else
				err "cannot delete '$d'"
				return 1
			fi
			break
		fi
	done
}


rm_all(){
	if [ ! -d /dev/block ];then
		err "directory, '/dev/block' is missing"
		return 1
	fi
	if [ ! -r /proc/mounts ];then
		err "cannot read /proc/mounts"
		return 1
	fi
	local f
	for f in $@;do
		_rm_all "$f"
	done
}

rm(){
	local VERBOSE_OPT
	if [ -n "$DEBUG" ];then
		VERBOSE_OPT="-v"
	fi
	if [ "$1" = "-rf" ];then
		shift
		rm_all $@
	else
		$__sudo__ /bin/rm $@
	fi
}

