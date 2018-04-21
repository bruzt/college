#!/bin/bash

# Verifica se o script está sendo executado com privilégios root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Versão do script
VERSION="DkScale	0.11"

# Diretorio dos logs
LOGDIR='/var/log/dkscale'

# Verifica se o diretorio dos logs existe, caso não ele o cria
if [ ! -d "$LOGDIR" ]; then
	mkdir $LOGDIR
fi

# Coloca o endereço dos logs em variaveis
SCALELOG=$LOGDIR/scale.log			# Log do escalonamento
ERRLOG=$LOGDIR/err.log				# Log de erro
SERVPIDLOG=$LOGDIR/servpid.log
NODESFILE=$LOGDIR/nodes.log

# Logs de escalonamento e erro
touch $SCALELOG
touch $ERRLOG
touch $SERVPIDLOG
touch $NODESFILE


###########################################
USER=pi

MINCPU=10
MINMEMORY=10

MAXCPU=90
MAXMEMORY=90

MINREPLICAS=1
MAXREPLICAS=10

TIME=60

NUMBERS='^[0-9]+$'	# Para verificar se é um numero


# Função para exibir um menu de ajuda, mostrando as opções iniciais
function dkshelp {
	echo 	"
		dkscale auto [option]

		auto		auto-scale option
		-h, --help	Help menu
		show		Show the services in monitoring
		stop		Stop monitoring a service
		-v, --version	Show dkscale version
		"
}

function show {
	cat $SERVPIDLOG | awk '{print $1}'	# Printa o nome dos serviços que estão sendo monitorados

}

function stop {
	shift
	SERVICE=$1
	if [ -z $SERVICE ];then		# Se não ouver nada em $service
		echo 	"
			dkscale stop [service] 		
			"
		exit 1
	fi

	PIDK=$(cat $SERVPIDLOG | grep -w $SERVICE | awk '{print $2}' 2> /dev/null)
	if [ -z "$PIDK" ];then	# -z retorna true se a variavel estiver vazia
		echo "Service not found"
		exit 1		# Finaliza o scrip caso o serviço não seja encontrado
	fi
	
	kill $PIDK		# Mata o processo
	cat $SERVPIDLOG | grep -v $1 > $SERVPIDLOG	# Remove do log o processo finalizado
	rm -rf $LOGDIR/$SERVICE
	printf "Stopping monitoring $SERVICE\n"		# printa mensagem
}

# função que verificará as condições do serviço
function auto {
#	op=$1	# Variavel $1 nessa função é a $2 na main
	shift

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
					--time=60		Time in seconds to wait after make a Scale action. Default: 60
					"
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
					echo "time invalid!"
					exit 1
				fi
			;;

			--mincpu)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINCPU=$1
				else
					echo "mincpu invalid!"
					exit 1
				fi
			;;

			--maxcpu)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXCPU=$1
				else
					echo "maxcpu invalid!"
					exit 1
				fi
			;;

			--minmemory)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINMEMORY=$1
				else
					echo "time invalid!"
					exit 1
				fi
			;;

			--maxmemory)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXMEMORY=$1
				else
					echo "maxmemmory invalid!"
					exit 1
				fi
			;;
			
			--minreplicas)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MINREPLICAS=$1
				else
					echo "minreplicas invalid!"
					exit 1
				fi
			;;

			--maxreplicas)
				shift
				if [[ $1 =~ $NUMBERS ]];then
					MAXREPLICAS=$1
				else
					echo "maxreplicas invalid!"
					exit 1

				fi
			;;

		esac
		shift

	done

	#echo "$SERVICE - $USER - $TIME - $MAXREPLICAS - $MINREPLICAS - $MAXMEMORY - $MINMEMORY - $MAXCPU - $MINCPU"


#	if [ -z $SERVICE ];then
#   		echo "Service not found"
#   		exit 1		# Finaliza o scrip caso o serviço não seja encontrado
#	fi

	# Procura nos serviços pelo serviço desejado
	SERVTAM=$(docker service ls | awk '{print $2}' | grep -w $SERVICE | wc -l)	# wc -l conta as linhas	 
		
	# Só deve haver 1 ocorrencia do serviço, qualquer numero diferente de 1 ou o serviço não existe ou o nome está incorreto
	if [ "$SERVTAM" -ne "1" ];then		# -ne = not equal					
   		echo "Service not found"
   		exit 1		# Finaliza o scrip caso o serviço não seja encontrado
	fi

	# Verifica se o serviço já esta sendo monitorado
	SERVTAM=$(cat $SERVPIDLOG | grep -w $SERVICE | wc -l)
	if [ "$SERVTAM" -ne "0" ];then
		echo "Service already monitored"
		exit 1
	fi

	printf "Monitoring $SERVICE\n"		# printa mensagem de monitoramento
	# Executa o scalonamento no background
	scale $SERVICE &	# Roda a função em background

}

function scale {
	SERVICE=$1

	# Cria o diretorio do serviço
	if [ ! -d "$LOGDIR/$SERVICE" ]; then
		mkdir $LOGDIR/$SERVICE
	fi

	# Coloca o endereço dos logs do serviço em variaveis
	RESFILE=$LOGDIR/$SERVICE/resources.log
	PROCFILE=$LOGDIR/$SERVICE/proc.log
	MEMFILE=$LOGDIR/$SERVICE/mem.log

	# Cria os arquivos de log do serviço
	touch $RESFILE
	touch $PROCFILE
	touch $MEMFILE		

	# Contador que controlará a quantidade de réplicas, seu valor inicial é igual a quantidade atual de réplicas
	COUNT="$(docker service ls | grep -w $SERVICE | awk '{print $4}')"
	COUNT="${COUNT:2:3}"	# Seleciona da variavel count, apos o segundo caractere os três caracteres subsequentes (Seleciona o numero total de replicas -/X)
	PID="$(ps -eo uid,pid,cmd | grep -w 0 | grep -w auto | grep -w $SERVICE | awk '{print $2}' | sed '1!d')"	# pega o PID do processo
	echo "$SERVICE	$PID" >> $SERVPIDLOG	# Salva o nome do serviço e o PID desse processo

	while [ '1' ];do

		# Verifica e filtra o uso da CPU e Memória do serviço e suas réplicas e salva no log
		docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | grep -w $SERVICE > $RESFILE

		# Retorna o nome de todos os nodes que o serviço esta rodando exceto este
		docker node ps | sed -n '1!p' | grep 'Running' | grep -w $SERVICE | awk '{print $4}' | grep -v hostname > $NODESFILE 

		if [ ! -s $NODESFILE ];then
			# Pega o endereço ip de todos os nodes que o serviço está rodando
			while read -r LINE
			do
				NODEIP=$(docker node inspect $LINE --format '{{ .Status.Addr  }}')
				sed -i "s/$LINE/$LINE	$NODEIP/g" $NODESFILE
			done < "$NODESFILE"
			
			# Conecta nos nodes para pegar os dados do serviço
			ssh $USER@$(awk 'print $2' $NODESFILE) sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | grep -w $SERVICE >> $RESFILE
		fi		

		# Verifica se o serviço continua existindo
		if [ ! -s $RESFILE ];then
			stop $SERVICE
			exit 1
		fi

		awk '{print $2}' $RESFILE > $PROCFILE	# Grava a segunda coluna do resfile em procfile
		sed -i 's/%//' $PROCFILE		# Remove o simbolo '%'
		awk '{print $3}' $RESFILE > $MEMFILE	# Grava a terceira coluna do resfile em memfile
		sed -i 's/%//' $MEMFILE			# Remove o simbolo '%'
	
		LINES=$(wc -l < $PROCFILE) # Conta o numero de linhas no arquivo, que é igual ao numero de réplicas

		# Tira a média aritimética do uso de CPU de todas as replicas do serviço
		PROC=0.0
		while read -r LINE
		do
		    PROC=$(awk "BEGIN {print $PROC+$LINE; exit}")
		done < "$PROCFILE"
		PROC=$(awk "BEGIN {print int($PROC/$LINES); exit}") 	# Variavel contendo a média da CPU
		
		# Defina a porcentagem da média de uso da CPU
		CPU=$(docker service inspect $SERVICE | grep "NanoCPUs" | tr -d '"NanoCPUs":' | tr -d ',' | head -n1)
		if [ -z $CPU ];then
			CPU=100
		else
			CPU=$(awk "BEGIN {print $CPU/10000000; exit}")
		fi
		CPU=$(awk "BEGIN {print int(($PROC/$CPU)*100); exit}")

		# Tira a média aritimética do uso de Memória de todas as replicas do serviço 
		MEM=0.0
		while read -r LINE
		do
		    MEM=$(awk "BEGIN {print $MEM+$LINE; exit}")
		done < "$MEMFILE"
		MEM=$(awk "BEGIN {print int($MEM/$LINES); exit}")	# Variavel contendo a média da Memoria
		
		# Faz o escalonamento		
		# Se o serviço esta usando menos de 10% do total de processamento ou menos de 30% do total de memoria ele mata uma replica
		if [ "$CPU" -le "$MINCPU" ] && [ $COUNT -gt "$MINREPLICAS" ];then	# -le = menor ou igual, -gt = maior que
			if [ "$MEM" -le "$MINMEMORY" ] && [ $COUNT -gt "$MINREPLICAS" ];then
				COUNT=$(awk "BEGIN {print $COUNT-1; exit}")	# Decrescenta o contador
				SERVSCALE=$SERVICE'='$COUNT
				sudo docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
				echo "$(date +"%d-%m-%Y") at $(date +"%T") Scale DOWN service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log

				sleep $TIME
			fi

		# Se o serviço esta usando mais de 90% do total de processamento ou mais de 70% do total de memoria ele cria uma nova replica
		elif ([ "$CPU" -ge "$MAXCPU" ] && [ $COUNT -lt "$MAXREPLICAS" ]) || ([ "$MEM" -ge "$MAXMEMORY" ] && [ $COUNT -lt "$MAXREPLICAS" ]);then 	# -ge = maior ou igual, -lt = menor que
			COUNT=$(awk "BEGIN {print $COUNT+1; exit}")	# Incrementa o contador
			SERVSCALE=$SERVICE'='$COUNT
			sudo docker service scale $SERVSCALE 1> /dev/null 2>> $ERRLOG
			echo "$(date +"%d-%m-%Y") at $(date +"%T") Scale UP service $SERVICE to $COUNT" >> $SCALELOG	# Salva no log
		
			sleep $TIME
		fi
	done
}

################## MAIN #########################

while test $# -gt -1
do
    case "$1" in
	-h) 
		dkshelp
		exit 0
	;;
	--help) 
		dkshelp
		exit 0
	;;

	-v) 
		echo $VERSION
		exit 0
	;;
	--version) 
		echo $VERSION
		exit 0
	;;

	auto) 
		auto "$@"
		exit 0
	;;

	show) 
		show
		exit 0
	;;

	stop) 
		stop "$@"
		exit 0
	;;

	*) 
		dkshelp
		exit 0
	;;
    esac

    shift
done
