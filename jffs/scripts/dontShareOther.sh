#!/bin/sh

# 整段数据, 如果section变量为空, 则表示不用复制当前行
section=''
# validuser 和 invaliduser数据, 两个相同时就是不会共享的文件夹, 放弃当前段
valid='N/A'
invalid='N/A'

while read -r line
do
	# 检查是不是段名
	flag=`echo ${line} | grep '^\[[^]]\+\]\s*$'`	
	if test -n "$flag";	then # 如果是段名, 先输出前一段的数据(如果有的话), 然后初始化三个变量
		if test -n "$section"; then echo $section | sed 's/\\n/\n/g'; fi
		section=$flag
		valid='N/A'
		invalid='N/A'
	elif test -n "$section"; then # 如果不是段名, 就是段内数据了	
		# 叠加当前行到section变量中
		section=${section}"\n"${line}

		# 检查是不是valid=xxx
		flag=`echo ${line} | grep "^valid users *=" | sed 's/valid users *= *\(.*\)/\1/'`
		if test -n "$flag"; then
			# 如果是的话, 存入valid变量, 并对比invalid变量, 如果相同就清空section, 当前段放弃
			valid=$flag
			if test "$invalid" = "$valid"; then section=''; fi
		else
			# 再检查是不是invalid=xxx				
			flag=`echo ${line} | grep "^invalid users *=" | sed 's/invalid users *= *\(.*\)/\1/'`
			if test -n "$flag"; then
				# 如果是的话, 存入invalid变量, 并对比valid变量, 如果相同就清空section, 当前段放弃
				invalid=$flag
				if test "$invalid" = "$valid"; then section=''; fi
			fi
		fi
	fi
done

# 最后一段数据
if test -n "$section"; then echo $section | sed 's/\\n/\n/g'; fi
