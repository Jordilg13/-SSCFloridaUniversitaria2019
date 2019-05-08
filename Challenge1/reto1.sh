#!/bin/bash
function main () {
    # 
    # imprime menu principal y llama la funcion main
    # 
   echo "------------"
   echo "| A PESCAR |"
   echo "------------"
   echo "1.Jugar"
   echo "2.Salir"
   echo ""
   read -p "Introduce una opcion: " op
   clear

   case "$op" in
       1)   PARTIDA  ;;
       2)   end=1  ;;
       *)   echo "Opcion invalida, introduce 1 para jugar o 2 para salir."  ;;
   esac
   
}

function generar_baraja(){   # se genera la baraja con los 4 palos i los 12 nuemeros por cada palo, o=oros, b=bastos...
	for palo in o b e c; do
		for num in $(seq 1 12); do
            baraja+=("$palo:$num ")
		done
	done
}
function repartir_cartas () {  # se reparten 7 cartas de la baraja a cada jugador

    for i in $(seq 7); do
        # cartas jugador
        carta_aleatoria
        cartas_jugador+=($carta_actual)
        # cartas maquina
        carta_aleatoria
        cartas_maquina+=($carta_actual)
    done

}

function carta_aleatoria(){		        # genera una carta aleatoria(palo+numero) que no se haya generado anteriormente
    rand=$((RANDOM % ${#baraja[*]}))	# random entre 0 i los elementos que contenga la baraja
    carta_actual=${baraja[$rand]}
    unset baraja[$rand]	                # se desasigna la carta para evitar repeticiones
    baraja=(${baraja[@]})	            # se re asigna para eliminar los indices vacios que deja el unset


}

function tablero() {  # imprime el tablero dinamico
    clear
    echo -e "\n"
    echo -e """

|;;Tus cartas: ${cartas_jugador[@]};;|;; Pila de cartas: ${#baraja[@]} cartas;;|
|;; ;;|;; ;;|
|;; ;;|;; Tu pila: ${pila_jugador[@]};;|
|;; ;;|;; Pila maquina: ${pila_maquina[@]} ;;|

""" | column -t -s ";;"
echo -e "\n"
}

function PARTIDA () { # funcion principal
    generar_baraja
    repartir_cartas

    comprobar_si_se_tienen_cuatro_cartas cartas_jugador pila_jugador
    comprobar_si_se_tienen_cuatro_cartas cartas_maquina pila_maquina

    turnos

}

function turnos () {   # bucle que gestiona los turnos
    end_turnos=0
    turno_actual=0
    last_choice=0

    while [ $end_turnos -eq 0 ]; do
        tablero
        if [ $(($turno_actual%2)) -eq 0 ]; then  # si actual turno es divisible entre 2, es turno del usuario, si no de la maquina
            errctrl=0
            # pregunta por la carta hasta que sea valida
            while [[ $errctrl -eq 0 ]]; do
                read -p "Que carta deseas solicitar? " carta_solicitada
                controlar_carta_solicitada $carta_solicitada
                errctrl=$?
            done
            solicitar_carta "u" $carta_solicitada

        else
            solicitar_carta "m"
        fi
        ((turno_actual++)) # pasa de turno

        comprobar_fin_juego
        
    done
    
}
function controlar_carta_solicitada() {   # controla si la carta introducida es valida
    result=0
    if [[ "$1" =~ (^0?[1-9]$)|(^1[0-2]$) ]];then  # solo permite un int entre 1 y 12
        result=1
    else
        echo "Formato invalido, introduzca un numero entre 1 y 12."
        pulsa_enter
    fi
    return $result
}

function solicitar_carta() {
    if [ $1 == "u" ]; then  # si el solicitante es el usuario
        comprobar_solicitada_esta_en_mano $2 cartas_jugador cartas_maquina 0
        if [[ $? -eq 0 ]];then
            robar_carta_baraja cartas_jugador "A pescar! \nRobas de la pila de cartas. \nHas robado: " "u"
        fi
        comprobar_si_se_tienen_cuatro_cartas cartas_jugador pila_jugador
        
    else        # si el solicitante es la maquina
        logica_maquina  # elige un numero
        random_number=$?
        echo "Tu contrincante pide un $random_number."
        pulsa_enter  # read para mayor legibilidad 
        comprobar_solicitada_esta_en_mano $random_number cartas_maquina cartas_jugador 1  # comprueba si la carta solicitada esta en la mano del solicitado

        if [[ $? -eq 0 ]];then  # si no esta, roba una carta de la baraja
            robar_carta_baraja cartas_maquina "A pescar! \nTu contrincante roba de la pila de cartas." "m"
        fi
        comprobar_si_se_tienen_cuatro_cartas cartas_maquina pila_maquina  # se comprueba si se pueden descartar cartas
    fi
    
}

function comprobar_solicitada_esta_en_mano() { 
    ###
    #
    # Funion generica, se le passan dos arrays(cartas soolicitante y cartas solicitado) y se comprueba que la carta pedida
    # esta en la mano del solicitado, si lo està, se le roba esa carta, y asi para todas las cartas en la mano del solicitado
    # con el mismo valor numerico. (Los valores de los arrays se autoasignan a cartas_jugador y cartas_maquina)
    #
    ###
    local number=$1 
    local -n cartas_solicitante=$2
    local -n cartas_solicitado=$3
    local result=0
    cartas_robadas=()
    
    # itera sobre las cartas del solicitado y comprueba si tiene cartas con el numero solicitado
    for i in $(seq 0 $((${#cartas_solicitado[@]}-1)) ); do

        if [ $(echo ${cartas_solicitado[$i]} | cut -d: -f2) -eq $number ]; then
            
            # se añade la carta robada a la mano del solicitante
            cartas_solicitante+=("${cartas_solicitado[$i]}")

            cartas_robadas+=(${cartas_solicitado[$i]}) # se guardan las cartas robadas para posterior eliminacion de la mano del solicitado

            # desasigna la carta enviada de la mano del solicitado
            unset_item_of_array $i cartas_solicitado

            # se cambia el numero de turno para que vuelva a jugar el jugador que acaba de robar
            turno_actual=$(($4-1))    
            result=1     # se especifica que el jugador ha robado
        fi
        
    done
    # si se ha robado cartas, se imprimen
    if [[ ${#cartas_robadas[@]} -ne 0 ]];then
        echo "Cartas robadas: ${cartas_robadas[@]}"
        pulsa_enter
    fi

    # se regenera el array para limpiar los indices vacios
    cartas_solicitado=( "${cartas_solicitado[@]}" )
    return $result
}

function unset_item_of_array(){ # desasigna  un item especiffico de un array que se le pasa como argumento
    local -n arr=$2

    unset arr[$1]
    temporal_array=( "${arr[@]}" )
}

function comprobar_si_se_tienen_cuatro_cartas() {  
    # comprueba si se tiene 4 cartas con el mismo valor numerico, si se tiene, se mueven de la mano a la pila del usuario
    local -n cartas_solicitante=$1
    local -n pila=$2
    local cont=0
    local last_number=0
    array_pivote=() # array temporal
    cartas_a_borrar=()


    array_pivote=$(printf "%s\n" "${cartas_solicitante[@]}" | sort -n -t':' -k2)  # se ordena el array(por numero) para posterior tratamiento
    array_pivote=($(echo ${array_pivote[@]} | tr "\r\n" " ")) # se repara el formato

    # recorre el array ordenado
    for ((i=0;i<${#array_pivote[@]};i++)); do 

        # se van contando las cartas repetidas y sumando si se van repitiendo, se compara la acutal y la anterior y va sumandose al contador
        if [[ $last_number -eq $(echo ${array_pivote[$i]} | cut -d: -f2) ]];then 
            ((cont++))
        else # si el numero no es igual al anterior resetea el contador
            cont=0
        fi

        # si el contador llega a 3(4 cartas), se resetea el contador y se guarda el valor de las cartas a descartar
        if [[ $cont -eq 3 ]];then
            cartas_a_borrar+=($last_number)
            cont=0
        fi
        last_number=$(echo ${array_pivote[$i]} | cut -d: -f2)
    done

    # descarta de la mano las cartas
    for i in ${cartas_a_borrar[@]}; do
        regex=([eobc]:$i)
        cartas_solicitante=($(printf "%s\n" "${cartas_solicitante[@]}" | grep -v -w $regex))
        echo "Cartas con valor ${cartas_a_borrar[@]} añadidas a la pila. "
        pulsa_enter
    done
    
    pila+=(${cartas_a_borrar[@]}) # se suman las cartas a la pila
    
}
function comprobar_fin_juego() {
    # si no hay cartas ni en las manos de los jugadores ni en la baraja, se termina la partida
    if [[ ${#cartas_jugador[@]} -eq 0 ]] && [[ ${#cartas_maquina[@]} -eq 0 ]] && [[ ${#baraja[@]} -eq 0 ]];then
        clear
        echo -e "Fin del juego.\n---------------\n"
        if [[ ${#pila_jugador[@]} -gt ${#pila_maquina[@]} ]];then
            echo "Has ganado!!!"
        elif [[ ${#pila_jugador[@]} -lt ${#pila_maquina[@]} ]];then
            echo "Has perdido."
        else
            echo "Has empatado con la maquina."
        fi
    
        echo -e "\nTus puntos: ${#pila_jugador[@]}"
        echo "Puntos maquina: ${#pila_maquina[@]}"

        # reset variables
        unset cartas_jugador
        unset cartas_maquina
        unset pila_jugador
        unset pila_maquina

        pulsa_enter "ENTER para continuar"
        end_turnos=1
    fi

}
function robar_carta_baraja() {
    # roba una carta de la baraja
    local -n temp=$1

    # comprueba si quedan cartas en la baraja
    if [[ ${#baraja[@]} -ne 0 ]];then
        carta_aleatoria
        if [[ $3 == "u" ]];then
            echo -e $2 $carta_actual
        else
            echo -e $2
        fi
        
        temp+=($carta_actual) 
    else
        echo -e "No quedan mas cartas en la baraja."
    fi
    pulsa_enter


}

function pulsa_enter() {
    # texto que arpadea para dar visibilidad al script
    echo -e "\033[5mENTER para continuar.\033[0m"
    read
}

function logica_maquina(){
    # un minimo de logica al elegir el numero que preguntara la maquina
    # empieza preguntando un numero del 1 al 12, que se van reduciendo a medida que se descartan cartas
    # una vez un numero se ha descartado, la maquina no vuelve a preguntar por el
    # de forma que solo pregunta por cartas que aun estan en juego
    local choice=0
    posibilidades_totales=($(seq 1 12)) #array de posibildades del 1 al 12(consante)
    posibilidades_este_turno=(${posibilidades_totales[@]})  # posibilidades en cada turno(copia)
    filters=("${pila_jugador[@]}" "${pila_maquina[@]}") # se añaden a los filtros los valores de ambas pilas
    
    # se recorren los filtros
    for i in ${filters[@]}; do
        posibilidades_este_turno=($(printf "%s\n" "${posibilidades_este_turno[@]}" | grep -v -w $i))  # se van quitando los valores de no se van a poder elegir
    done
    ran=$(( RANDOM % ${#posibilidades_este_turno[@]} ))  # se elige el numero que la maquina va a elegir, entre 0 y el numero de possibilidades

    choice=${posibilidades_este_turno[$ran]}  # se asigna la eleccion

    return $choice
}
# MAIN
end=0

while [ $end -eq 0 ]; do
    main  
done

