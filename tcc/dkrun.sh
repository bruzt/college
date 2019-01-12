#!/bin/bash

source /usr/local/sbin/dkset.sh

while true
do
	if [ -s $SERVPIDLOG ]	# -s retorna true se o arquivo existe e tem o tamanho maior que 0 (tem alguma coisa escrita nele)
	then	
		while read -r LINE
		do
			SERVNAME=$(echo $LINE | awk '{print $1}')
			SERVPID=$(echo $LINE | awk '{print $2}')

			TESTPID=$(ps -eo pid,cmd | grep -w $SERVNAME | grep -w $SERVPID | grep -v "grep" | awk '{print $1}')
			if [ -z $TESTPID ] 
			then		
				COMMAND=$(cat $PARAMETERSLOG | grep -w $SERVNAME)
				cat $SERVPIDLOG | grep -v $SERVNAME > $SERVPIDLOG
				cat $PARAMETERSLOG | grep -v $SERVNAME > $PARAMETERSLOG

				dkscale auto $COMMAND 
			fi

		done < "$SERVPIDLOG"
	fi

	sleep 10
done
