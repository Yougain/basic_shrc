_rm_all(){
	local force_opt="$2"
	if [ ! -e "$1" ];then
		if [ "$force_opt" = true ];then
			return 0
		fi
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
	if [ "$d" = "/" -o "$d" = "~" ];then
		err "cannot use rm_all to '$d'"
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
				$__sudo__ /bin/rm $([ "$force_opt" = true ] && echo "-f") $VERBOSE_OPT --one-file-system -rf "$d"
			else
				err "cannot delete '$d'"
				return 1
			fi
			break
		fi
	done
}


rm_all(){
	local force_opt="$1"
	shift
	if [ ! -d /dev/block ];then
		err "directory, '/dev/block' is missing"
		return 1
	fi
	if [ ! -r /proc/mounts ];then
		err "cannot read /proc/mounts"
		return 1
	fi
	local f
	for f in "$@";do
		echo $f
		_rm_all "$f" "$force_opt"
	done

}

rm(){
	local has_r=false
	local has_f=false
	for arg in "$@"; do
		case "$arg" in
			--) break ;;                      # 以降はオプション扱いしない
			-r|-R|--recursive) has_r=true ;;
			-f|--force) has_f=true ;;
			-[!-]*[rR]*) has_r=true ;; # -rf, -fr, -irf など
			-[!-]*f*) has_f=true ;;
		esac
	done
	local VERBOSE_OPT
	if [ -n "$DEBUG" ];then
		VERBOSE_OPT="-v"
	fi
	if [ "$has_r" = true ];then
		local rm_targets=()
		local after_ddash=false
		for arg in "$@";do
			if [ "$after_ddash" = true ];then
				rm_targets+=("$arg")
				continue
			fi
			case "$arg" in
				--) after_ddash=true ;;
				-*) ;;
				*) rm_targets+=("$arg") ;;
			esac
		done

		if [ ${#rm_targets[@]} -eq 0 ];then
			if [ "$has_f" = true ];then
				return 0
			fi
			err "missing operand"
			return 1
		fi

		rm_all "$has_f" "${rm_targets[@]}"
	else
		$__sudo__ /bin/rm "$@"
	fi
}

