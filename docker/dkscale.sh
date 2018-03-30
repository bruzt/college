#!/bin/bash

# Verifica se o script está sendo executado com privilégios root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Versão do script
VERSION="DkScale	0.9"

# Diretorio dos logs
logdir='/var/log/dkscale'

# Verifica se o diretorio dos logs existe, caso não ele o cria
if [ ! -d "$logdir" ]; then
	mkdir $logdir
fi

# Coloca o endereço dos logs em variaveis
scalelog=$logdir/scale.log			# Log do escalonamento
errlog=$logdir/err.log			# Log de erro
servpidlog=$logdir/servpid.log
nodesfile=$logdir/nodes.log

# Logs de escalonamento e erro
touch $scalelog
touch $errlog
touch $servpidlog
touch $nodesfile


###########################################
user=pi



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
	cat $servpidlog | awk '{print $1}'	# Printa o nome dos serviços que estão sendo monitorados

}

function stop {
	service=$1
	if [ -z $service ];then		# Se não ouver nada em $service
		echo 	"
			dkscale stop [service] 		
			"
		exit 1
	fi

	pidk=$(cat $servpidlog | grep -w $service | awk '{print $2}' 2> /dev/null)
	if [ -z "$pidk" ];then	# -z retorna true se a variavel estiver vazia
		echo "Service not found"
		exit 1		# Finaliza o scrip caso o serviço não seja encontrado
	fi
	
	kill $pidk		# Mata o processo
	cat $servpidlog | grep -v $1 > $servpidlog	# Remove do log o processo finalizado
	rm -rf $logdir/$service
	printf "Stopping monitoring $service\n"		# printa mensagem
}

# função que verificará as condições do serviço
function auto {
	op=$1	# Variavel $1 nessa função é a $2 na main

	if [ "$op" == "--name" ];then
		service=$2	# Variavel $2 nessa função é a $3 na main

#		if [ -z $service ];then
#   			echo "Service not found"
#   			exit 1		# Finaliza o scrip caso o serviço não seja encontrado
#		fi

		# Procura nos serviços pelo serviço desejado
		servtam=$(docker service ls | awk '{print $2}' | grep -w $service | wc -l)	# wc -l conta as linhas	 
		
		# Só deve haver 1 ocorrencia do serviço, qualquer numero diferente de 1 ou o serviço não existe ou o nome está incorreto
		if [ "$servtam" -ne "1" ];then		# -ne = not equal					
   			echo "Service not found"
   			exit 1		# Finaliza o scrip caso o serviço não seja encontrado
		fi

		# Verifica se o serviço já esta sendo monitorado
		servtam=$(cat $servpidlog | grep -w $service | wc -l)
		if [ "$servtam" -ne "0" ];then
			echo "Service already monitored"
			exit 1
		fi

		printf "Monitoring $service\n"		# printa mensagem de monitoramento
		# Executa o scalonamento no background
		scale $service &	# Roda a função em background

	else
		echo 	"
			dkscale auto --name [service] 		
			"
	fi
}

function scale {
	service=$1

	# Cria o diretorio do serviço
	if [ ! -d "$logdir/$service" ]; then
		mkdir $logdir/$service
	fi

	# Coloca o endereço dos logs do serviço em variaveis
	resfile=$logdir/$service/resources.log
	procfile=$logdir/$service/proc.log
	memfile=$logdir/$service/mem.log

	# Cria os arquivos de log do serviço
	touch $resfile
	touch $procfile
	touch $memfile		

	# Contador que controlará a quantidade de réplicas, seu valor inicial é igual a quantidade atual de réplicas
	count="$(docker service ls | grep -w $service | awk '{print $4}')"
	count="${count:2:3}"	# Seleciona da variavel count, apos o segundo caractere os três caracteres subsequentes (Seleciona o numero total de replicas -/X)
	pid="$(ps -eo uid,pid,cmd | grep -w 0 | grep -w auto | grep -w $service | awk '{print $2}' | sed '1!d')"	# pega o PID do processo
	echo "$service	$pid" >> $servpidlog	# Salva o nome do serviço e o PID desse processo

	while [ '1' ];do

		# Verifica e filtra o uso da CPU e Memória do serviço e suas réplicas e salva no log
		docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | grep -w $service > $resfile

		
		# Retorna o nome de todos os nodes que o serviço esta rodando exceto este
		docker node ps | sed -n '1!p' | grep 'Running' | grep -w $service | awk '{print $4}' | grep -v hostname > $nodesfile 

		if [ ! -s $nodesfile ];then
			# Pega o endereço ip de todos os nodes que o serviço está rodando
			while read -r line
			do
				nodeip=$(docker node inspect $line --format '{{ .Status.Addr  }}')
				sed -i "s/$line/$line	$nodeip/g" $nodesfile
			done < "$nodesfile"
			
			# Conecta nos nodes para pegar os dados do serviço
			ssh $user@$(awk 'print $2' $nodesfile) sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}" | grep -w $service >> $resfile
		fi		

		# Verifica se o serviço continua existindo
		if [ ! -s $resfile ];then
			stop $service
			exit 1
		fi

		awk '{print $2}' $resfile > $procfile	# Grava a segunda coluna do resfile em procfile
		sed -i 's/%//' $procfile		# Remove o simbolo '%'
		awk '{print $3}' $resfile > $memfile	# Grava a terceira coluna do resfile em memfile
		sed -i 's/%//' $memfile			# Remove o simbolo '%'
	
		lines=$(wc -l < $procfile) # Conta o numero de linhas no arquivo, que é igual ao numero de réplicas

		# Tira a média aritimética do uso de CPU de todas as replicas do serviço
		proc=0.0
		while read -r line
		do
		    proc=$(awk "BEGIN {print $proc+$line; exit}")
		done < "$procfile"
		proc=$(awk "BEGIN {print int($proc/$lines); exit}") 	# Variavel contendo a média da CPU

		# Tira a média aritimética do uso de Memória de todas as replicas do serviço 
		mem=0.0
		while read -r line
		do
		    mem=$(awk "BEGIN {print $mem+$line; exit}")
		done < "$memfile"
		mem=$(awk "BEGIN {print int($mem/$lines); exit}")	# Variavel contendo a média da Memoria
		
		# Faz o escalonamento		
		if [ "$mem" -le "30" ] && [ $count -gt "1" ];then	# -le = menor ou igual, -gt = maior que
			count=$(awk "BEGIN {print $count-1; exit}")	# Decrescenta o contador
			servscale=$service'='$count
			sudo docker service scale $servscale 1> /dev/null 2>> $errlog
			echo "$(date +"%d-%m-%Y") at $(date +"%T") Scale DOWN service $service to $count" >> $scalelog	# Salva no log

		elif [ "$mem" -ge "70" ] && [ $count -lt "20" ];then 	# -ge = maior ou igual, -lt = menor que
			count=$(awk "BEGIN {print $count+1; exit}")	# Incrementa o contador
			servscale=$service'='$count
			sudo docker service scale $servscale 1> /dev/null 2>> $errlog
			echo "$(date +"%d-%m-%Y") at $(date +"%T") Scale UP service $service to $count" >> $scalelog	# Salva no log
		
		sleep 10s
		fi
	done
}

################## MAIN #########################

op=$1

if [ "$op" == "-h" ] || [ "$op" == "--help" ];then
	dkshelp

elif [ "$op" == "--version" ] || [ "$op" == "-v" ];then
	echo $VERSION

elif [ "$op" == "auto" ];then
	auto $2 $3

elif [ "$op" == "show" ];then
	show

elif [ "$op" == "stop" ];then
	stop $2

else
	dkshelp		
fi
