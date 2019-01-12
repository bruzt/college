#!/bin/bash

# Versao do script
VERSION="DkScale	1.2"

# Diretorio dos logs
LOGDIR='/var/log/dkscale'

# Verifica se o diretorio dos logs existe, caso nao ele o cria
if [ ! -d "$LOGDIR" ]; then
	mkdir $LOGDIR
fi

# Coloca o endereco dos logs em variaveis
SCALELOG=$LOGDIR/scale.log			# Log do escalonamento
ERRLOG=$LOGDIR/err.log				# Log de erro
SERVPIDLOG=$LOGDIR/servpid.log			# Log onde fica os nomes dos serviços monitorados e PIDs desses processos
PARAMETERSLOG=$LOGDIR/parameters.log		# Log onde fica os parametros dos monitoramentos

# Logs de escalonamento e erro
touch $SCALELOG
touch $ERRLOG
touch $SERVPIDLOG
touch $PARAMETERSLOG

# Variaveis com os valores padrao
###########################################
USER=root

MINCPU=10
MINMEMORY=10

MAXCPU=90
MAXMEMORY=90

MINREPLICAS=1
MAXREPLICAS=10

TIME=60

CPUONLY=1
MEMORYONLY=1
############################################

NUMBERS='^[0-9]+$'	# Para verificar se nao um numero

################################################
################# HELP ###########################
# Funcao para exibir um menu de ajuda, mostrando as opcoes iniciais
function dkshelp {
	echo 	"
	dkscale auto [option]

	auto		auto-scale option
	-h, --help	Help menu
	show		Show the services in monitoring
	stop		Stop monitoring a service
	-v, --version	Show dkscale version"
}

#############################################
#################### SHOW ###################
function show {
	cat $SERVPIDLOG | awk '{print $1}' 2>>$ERRLOG	# Printa o nome dos servicos que estao sendo monitorados

}

############################################
################### STOP #####################
function stop {
	shift
	SERVICE=$1
	if [ -z $SERVICE ];then		# Se nao ouver nada em $service
		echo 	"
			dkscale stop [service] 		
			"
		exit 1
	fi

	PIDK=$(cat $SERVPIDLOG | grep -w $SERVICE | awk '{print $2}' 2>>$ERRLOG)
	if [ -z "$PIDK" ];then	# -z retorna true se a variavel estiver vazia
		echo "Service not found"
		exit 1		# Finaliza o scrip caso o servico nao seja encontrado
	fi
	
	kill $PIDK		# Mata o processo
	cat $SERVPIDLOG | grep -v $SERVICE 1> $SERVPIDLOG 2>>$ERRLOG	# Remove do log o processo finalizado
	cat $PARAMETERSLOG | grep -v $SERVICE > $PARAMETERSLOG
	rm -rf $LOGDIR/$SERVICE					# Remove o diretorio do servico
	printf "Stopping monitoring $SERVICE\n"			# printa mensagem
}

############################################
################# AUTO #####################
# funcao que verificara as condicoes do servico
function auto {

	if [ "$(echo "$@" | awk '{print $1}')" == "auto" ]
	then
		shift
	fi

	echo "$@" 1>> $PARAMETERSLOG 2>>$ERRLOG

	while test $# -gt 0
	do

		case "$1" in

			--help)
				echo 	"
	dkscale auto --name [service] [Options]	

	--help			Show Menu.
	--mincpu		Minimum amount in % of CPU usage to Scale DOWN. Default: 10
	--minmemory		Minimum amount in % of RAM usage to Scale DOWN. Default: 10
	--maxcpu		Maximum amount in % of CPU usage to Scale UP. Default: 90
	--maxmemory		Maximum amount in % of RAM usage to Scale UP. Default: 90
	--minreplicas		Minimum number of replicas. Default: 1
	--maxreplicas		Maximum number of replicas. Default: 10
	--user			The username with admin privilege over docker engine. Default: root
	--time			Time, in seconds, to wait, after make a Scale action. Default: 60
	--cpuonly		Scale based on CPU usage only.
	--memoryonly		Scale based on Memory usage only."
				# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
				sed -i '$ d' $PARAMETERSLOG
				exit 1
			;;

			--name)
				shift
				SERVICE=$1
			;;

			--user)
				shift
				USER=$1
			;;

			--time)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					TIME=$1
				else
					echo "--time invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;

			--mincpu)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINCPU=$1
				else
					echo "mincpu invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;

			--maxcpu)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXCPU=$1
				else
					echo "maxcpu invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;

			--minmemory)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINMEMORY=$1
				else
					echo "time invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;

			--maxmemory)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXMEMORY=$1
				else
					echo "maxmemmory invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;
			
			--minreplicas)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINREPLICAS=$1
				else
					echo "minreplicas invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1
				fi
			;;

			--maxreplicas)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXREPLICAS=$1
				else
					echo "maxreplicas invalid!"
					# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
					sed -i '$ d' $PARAMETERSLOG
					exit 1

				fi
			;;

			--cpuonly)
				MEMORYONLY=0
			;;

			--memoryonly)
				CPUONLY=0
			;;

			*)
				echo "Invalid argument $1"
				# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
				sed -i '$ d' $PARAMETERSLOG
				exit 1
			;;

		esac
		shift

	done

	if [ -z $SERVICE ];then
   		echo "Service not found"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
   		exit 1		# Finaliza o scrip caso o servico nao seja encontrado
	fi

	# Verifica se o servico ja esta sendo monitorado
	SERVTAM=$(cat $SERVPIDLOG | grep -w $SERVICE | wc -l)
	if [ "$SERVTAM" -ne "0" ];then
		echo "Service already monitored"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
		exit 1
	fi

	if [ "$MINCPU" -ge "$MAXCPU" ];then		# -ge = maior ou igual
		echo "mincpu needs to be less than maxcpu"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
		exit 1
	fi

	if [ "$MINMEMORY" -ge "$MAXMEMORY" ];then
		echo "minmemory needs to be less than maxmemory"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
		exit 1
	fi

	if [ "$MINREPLICAS" -ge "$MAXREPLICAS" ];then
		echo "minreplicas needs to be less than maxreplicas"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
		exit 1
	fi

	if [ "$CPUONLY" -eq "0" ] && [ "$MEMORYONLY" -eq "0" ];then
		echo "--cpuonly and --memoryonly cannot be used together"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
		exit 1
	fi

	# Procura nos servicos pelo servico desejado
	SERVTAM=$(docker service ls | awk '{print $2}' | grep -w $SERVICE | wc -l)	# wc -l conta as linhas	 
		
	# So deve haver 1 ocorrencia do servico, qualquer numero diferente de 1 ou o servico nao existe ou o nome esta incorreto
	if [ "$SERVTAM" -ne "1" ];then		# -ne = not equal					
   		echo "Service not found"
		# cat $PARAMETERSLOG | grep -wv "$@" > $PARAMETERSLOG
		sed -i '$ d' $PARAMETERSLOG
   		exit 1		# Finaliza o scrip caso o servico nao seja encontrado
	fi

	printf "Monitoring $SERVICE\n"		# printa mensagem de monitoramento
	# Executa o scalonamento no background
	scale $SERVICE &	# Roda a funcao em background

}

##################################################
################# SCALE ##########################
function scale {
	SERVICE=$1

	# Cria o diretorio do servico caso nao exista
	if [ ! -d "$LOGDIR/$SERVICE" ]; then
		mkdir $LOGDIR/$SERVICE
	fi

	# Coloca o endereco dos logs do servico em variaveis
	RESFILE=$LOGDIR/$SERVICE/resources.log
	PROCFILE=$LOGDIR/$SERVICE/proc.log
	MEMFILE=$LOGDIR/$SERVICE/mem.log
	NODESFILE=$LOGDIR/$SERVICE/nodes.log
	IPSFILE=$LOGDIR/$SERVICE/ips.log

	# Cria os arquivos de log do servico
	touch $RESFILE
	touch $PROCFILE
	touch $MEMFILE
	touch $NODESFILE
	touch $IPSFILE

	# Contador que controlara a quantidade de replicas, seu valor inicial e igual a quantidade atual de replicas
	COUNT="$(docker service ls | grep -w $SERVICE | awk '{print $4}' 2>>$ERRLOG)"
	COUNT="${COUNT:2:3}"	# Seleciona da variavel count, apos o segundo caractere os tres caracteres subsequentes (Seleciona o numero total de replicas -/X)
	PID="$(ps -eo uid,pid,cmd | grep -w auto | grep -w dkscale | grep -w $SERVICE | awk '{print $2}' | sed '1!d')"	# pega o PID do processo
	echo "$SERVICE	$PID	$COUNT" 1>> $SERVPIDLOG 2>>$ERRLOG	# Salva o nome do servico e o PID desse processo

	DID=0 # Variavel que verifica se foi feito algum Scale
	while true
	do

		# Verifica se o servico continua existindo
		SERVTAM=$(docker service ls | awk '{print $2}' | grep -w $SERVICE | wc -l)	# wc -l conta as linhas	 
		if [ "$SERVTAM" -eq "0" ];then		# -eq = equal	
			cat $SERVPIDLOG | grep -v $SERVICE > $SERVPIDLOG	# Remove do log o processo finalizado	
			rm -rf $LOGDIR/$SERVICE					# Remove o diretorio do servico				
	   		exit 1
		fi

		MANAGER=$(docker node ls | grep -w $(hostname) | awk '{print $6}')
		if [ "$MANAGER" == "Leader" ]	# faz o processo se for o manager Leader
		then			

			COUNT=$(awk '{print $3}' $SERVPIDLOG)

			# Verifica e filtra o uso da CPU e Memoria das replicas do servico que estao rodando no manager e salva no log
			docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | grep -w $SERVICE 1> $RESFILE 2>>$ERRLOG

			# Retorna o nome de todos os nodes que o servico esta rodando exceto este
			docker service ps $SERVICE --format "table {{.Name}}\t{{.Node}}\t{{.DesiredState}}" | sed 's/\\\_//g' | sed -n '1!p' | grep 'Running' | grep -w $SERVICE | awk '{print $2}' | grep -v $(hostname) 1> $NODESFILE 2>>$ERRLOG

			if [ -s $NODESFILE ];then
				# Pega o endereco ip de todos os nodes que o servico esta rodando
				while read -r LINE
				do
					NODEIP=$(docker node inspect $LINE --format '{{ .Status.Addr  }}' 2>>$ERRLOG)
					sed -i "s/$LINE/$NODEIP/g" $NODESFILE
				done < "$NODESFILE"

				# Remove linhas duplicadas, caso tenha mais de uma replica em um mesmo nó
				awk '!a[$0]++' $NODESFILE > $IPSFILE
			
				# Conecta nos nodes para pegar os dados do servico
				while read -r LINE
				do
					CON=$USER'@'$LINE
					ssh -n $CON 'docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}"' | grep -w $SERVICE 1>> $RESFILE 2>>$ERRLOG
				done < "$IPSFILE"
			fi		

			awk '{print $2}' $RESFILE > $PROCFILE	# Grava a segunda coluna do resfile em procfile
			sed -i 's/%//' $PROCFILE		# Remove o simbolo '%'
			awk '{print $3}' $RESFILE > $MEMFILE	# Grava a terceira coluna do resfile em memfile
			sed -i 's/%//' $MEMFILE			# Remove o simbolo '%'
	
			LINES=$(wc -l < $PROCFILE) # Conta o numero de linhas no arquivo, que sao igual ao numero de replicas

			# Tira a media aritimetica do uso de CPU de todas as replicas do servico
			PROC=0.0
			while read -r LINE
			do
			    PROC=$(awk "BEGIN {print $PROC+$LINE; exit}")
			done < "$PROCFILE"
			PROC=$(awk "BEGIN {print int($PROC/$LINES); exit}") 	# Variavel contendo a media da CPU
		
			# Defina a porcentagem da media de uso da CPU
			CPU=$(docker service inspect $SERVICE | grep "NanoCPUs" | tr -d '"NanoCPUs":' | tr -d ',' | head -n1)
			if [ -z $CPU ];then
				CPU=100
			else
				CPU=$(awk "BEGIN {print $CPU/10000000; exit}")
			fi
			CPU=$(awk "BEGIN {print int(($PROC/$CPU)*100); exit}")

			# Tira a media aritimetica do uso de Memoria de todas as replicas do servico 
			MEM=0.0
			while read -r LINE
			do
			    MEM=$(awk "BEGIN {print $MEM+$LINE; exit}")
			done < "$MEMFILE"
			MEM=$(awk "BEGIN {print int($MEM/$LINES); exit}")	# Variavel contendo a media da Memoria
		
			DID=0 # Variavel que verifica se foi feito algum Scale
			if [ "$CPUONLY" -eq "1" ] && [ "$MEMORYONLY" -eq "1" ];then	
				# Faz o escalonamento baseado na CPU e Memoria
				# Se o servico esta usando menos de $MINCPU do total de processamento E menos de $MINMEMORY do total de memoria ele mata uma replica
				if [ "$CPU" -le "$MINCPU" ] && [ "$MEM" -le "$MINMEMORY" ] && [ "$COUNT" -gt "$MINREPLICAS" ];then	# -le = menor ou igual, -gt = maior que
					COUNT=$(awk "BEGIN {print $COUNT-1; exit}")	# Decrescenta o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale DOWN service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME
				

				# Se o servico esta usando mais de $MAXCPU do total de processamento OU mais de $MAXMEMORY do total de memoria ele cria uma nova replica
				elif ([ "$CPU" -ge "$MAXCPU" ] && [ "$COUNT" -lt "$MAXREPLICAS" ]) || ([ "$MEM" -ge "$MAXMEMORY" ] && [ "$COUNT" -lt "$MAXREPLICAS" ]);then 	# -ge = maior ou igual, -lt = menor que
					COUNT=$(awk "BEGIN {print $COUNT+1; exit}")	# Incrementa o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale UP service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME
				fi

			elif [ "$CPUONLY" -eq "1" ] && [ "$MEMORYONLY" -eq "0" ];then
			# Faz o escalonamento baseado apenas na CPU
				# Se o servico esta usando menos de $MINCPU do total de processamento ele mata uma replica
				if [ "$CPU" -le "$MINCPU" ] && [ "$COUNT" -gt "$MINREPLICAS" ];then	# -le = menor ou igual, -gt = maior que
					COUNT=$(awk "BEGIN {print $COUNT-1; exit}")	# Decrescenta o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale DOWN service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME

				# Se o servico esta usando mais de $MAXCPU do total de processamento ele cria uma nova replica
				elif [ "$CPU" -ge "$MAXCPU" ] && [ "$COUNT" -lt "$MAXREPLICAS" ];then 	# -ge = maior ou igual, -lt = menor que
					COUNT=$(awk "BEGIN {print $COUNT+1; exit}")	# Incrementa o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale UP service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME
				fi

			elif [ "$CPUONLY" -eq "0" ] && [ "$MEMORYONLY" -eq "1" ];then
			# Faz o escalonamento baseado apenas na Memoria
				# Se o servico esta usando menos de $MINMEMORY do total de memoria ele mata uma replica
				if [ "$MEM" -le "$MINMEMORY" ] && [ "$COUNT" -gt "$MINREPLICAS" ];then	# -le = menor ou igual, -gt = maior que
					COUNT=$(awk "BEGIN {print $COUNT-1; exit}")	# Decrescenta o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale DOWN service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME
				

				# Se o servico esta usando mais de $MAXMEMORY do total de memoria ele cria uma nova replica
				elif [ "$MEM" -ge "$MAXMEMORY" ] && [ "$COUNT" -lt "$MAXREPLICAS" ];then 	# -ge = maior ou igual, -lt = menor que
					COUNT=$(awk "BEGIN {print $COUNT+1; exit}")	# Incrementa o contador
					SERVSCALE=$SERVICE'='$COUNT
					docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
					echo "$(date +"%Y-%m-%d") at $(date +"%T") Scale UP service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
					DID=1
					sleep $TIME
				fi
			fi
		fi
		
		# Se não fez nenhum escalonamento 
		if [ "$DID" -eq "0" ];then
			sleep 5
		else
			# Atualiza o valor do contador no arquivo
			sed -i "s/$SERVICE	$PID	.*/$SERVICE	$PID	$COUNT/g" $SERVPIDLOG
		fi
	
	done
}





