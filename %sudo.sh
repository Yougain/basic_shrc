if [ "`id -u`" = 0 ];then
	__sudo(){
		$@
	}
else
	if [ -x /usr/bin/ruby ];then
		ruby<<END
			require 'pty'
			require 'etc'

			begin
				userName = Etc.getpwuid(Process.uid).name
			rescue ArgumentError
				exit 1
			end

			testStr = Random.rand(100000000).to_s
			PTY.spawn "sudo echo #{testStr}" do |r, w, pid|
				begin
					response = r.readpartial 2048
					case response
					when /^\[sudo\] password for #{Regexp.escape userName}:/
						Process.kill :INT, pid
						exit 0
					when /#{testStr}/
						exit 0
					else
						print response.ln
						exit 1
					end
				rescue EOFError
					exit 1
				end
			end
END
	else
		if perl -MIO::Pty -e1; then
			perl -e <<'END'
				use strict;
				use warnings;
				use IO::Pty;
				use POSIX;
				use English;

				# ユーザー名取得
				my $userName = getpwuid($<);
				if (!defined $userName) {
					exit 1;
				}

				# ランダム文字列生成
				my $testStr = int(rand(100000000));

				my $pty = IO::Pty->new;
				my $pid = fork();
				if (!defined $pid) {
					die "fork failed";
				}

				if ($pid == 0) {
					# 子プロセス
					$pty->make_slave_controlling_terminal();
					close $pty;
					exec("sudo", "echo", $testStr);
					exit 1;
				} else {
					# 親プロセス
					my $fh = $pty;
					eval {
						my $response = '';
						sysread($fh, $response, 2048);
						if ($response =~ /^\[sudo\] password for \Q$userName\E:/) {
							kill 'INT', $pid;
							exit 0;
						} elsif ($response =~ /$testStr/) {
							exit 0;
						} else {
							print $response . "\n";
							exit 1;
						}
					};
					exit 1 if $@;
				}
END
		else
			false
		fi
	fi
	SUDO_ABLE=$?
	if [ "$SUDO_ABLE" = "0" ];then
		__sudo(){
			/usr/bin/sudo $@
		}
	else
		__sudo(){
			/bin/su -c "$*"
		}
	fi
fi


su(){
    if [ -z "$@" ]; then
        if [ "$SUDO_ABLE" = "0" ]; then
            __sudo $SHELL
        else
        	/bin/su
        fi
    else
        /bin/su $@
    fi
}

#sudo(){
#	local __sudo__=sudo
#	case "$1" in
#		vi)
#			shift
#			__sudo vim $@
#			;;
#		rm)
#			__sudo__=/usr/bin/sudo
#			shift
#			rm $@
#			;;
#		*)
#			__sudo $@
#			;;
#	esac
#}

make(){
	if [ "$1" = "install" ]; then
		shift
		__sudo make install $@
	else
		/usr/bin/make $@
	fi
}

gem(){
	if [ "$1" = "install" ]; then
		shift
		__sudo gem install $@
	else
		/usr/bin/gem $@
	fi
}

rpm(){
	if [ -x `which ruby` ];then
	ruby <<END
	cmd = %w{$1}[0]
	cmds = %w{$*}
	if cmd[0] == ?- && cmd[1] != ?-
		if ENV['SUDO_ABLE'] == "0" && Process.euid != 0 && cmd =~ /[iUe]/ && !cmds.find{|e| e =~ /^[^\-].*\.src\.rpm$/}
			system *%w{/usr/bin/sudo /bin/rpm $*}
		else
			system *%w{/bin/rpm $*}
		end
	end
END
	else
		/bin/rpm "$@"
	fi
}


inst(){
	__sudo $IST -y install $@
}


upd(){
	__sudo $IST -y update $@
}



