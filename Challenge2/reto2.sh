#!/bin/bash
# VARIABLES 
end=0
campos_libros="título,autor,genero,año,estantería,prestado"
campos_usuarios="nombre,apellido1,apellido2,curso,num_préstamos"
campos_prestamos="id_libro,id_usuario"
APP_PATH="/home/$USER"

welcome(){
    # imprime el menu principal i lanza el subemnu dela opcion elegida
    local acabar=0
    clear
    echo """
--------------
| BIBLIOTECA |
--------------
  1.Gestion de libros
  2.Gestion de usuarios
  3.Gestion de prestamos
  4.Salir
    """
    read -p "Elige una opcion: " op
    case "$op" in
        1) submenu "libros";;
        2) submenu "usuarios";;
        3) submenu "prestamos";;
        4) echo "Cerrando..."
            acabar=1;;
        *) input_invalido;;
    esac
    return $acabar
}

submenu(){
    # genera un submenu diferente dependiendo de la opcion elegida
    local borde="$(echo "GESTION DE $1" | sed 's/./-/g')----" #se genera el borde dependiendo de la longitud del titulo
    local prestamo_op=""
    local sub_end=0
    local campos=campos_${1}

    while [ $sub_end -eq 0 ]; do
    clear
        echo """
$borde
| GESTION DE $(echo $1 | tr a-z A-Z) |
$borde
  1.Alta de $1
  2.Baja de $1
  3.Consulta de $1
  $([ $1 == "prestamos" ] && echo "4.Listado")
    """ # si se ha elegido prestamos se imprime tambien la opcion listado

        read -p "Elige una opcion(vacio para volver): " op

        if [[ $op == "" ]]; then
            sub_end=1
        elif [ $op -eq 1 ]; then
            alta $1 $campos
        elif [ $op -eq 2 ]; then
            baja $1 $campos
        elif [ $op -eq 3 ]; then
            consulta $1 $campos
        elif [[ $op -eq 4 && $1 == "prestamos" ]]; then # solo se permite la opcion 4 en prestamos
            listado $1
        else
            input_invalido
        fi
    done

}

alta() {
    # genera una alta de la opcion elegida, el id se gnera cogiendo el ultimo id del fichero y sumandole 1
    comprobar_si_ficheros_existen    # comprueba si existe la estructura de ficheros
    case "$1" in
        "libros"|"usuarios")  
        pedir_campos=1
        while [ $pedir_campos -eq 1 ]; do
            echo "${!2}" # variable variable, imprime los campos de la opcion elegida
            read -p "Introduce los campos especificados separados por comas: " campos_in
            campos_to_check=$(echo $campos_in | tr "," " ")
            campos_to_check=($campos_to_check) # se genera array de las opciones introduccidas

            if [[ ${campos_to_check[${#campos_to_check[@]}-1]} =~ ^-?[0-9]+$ ]];then  # se comprueba que el ultimo campo sea un numero(ya sea prestado de libros o num_prestamos de usuarios)
                echo $(($(tail $APP_PATH/biblioteca/$1.bd -n1 2> /dev/null | cut -d"," -f1)+1)),$campos_in >> $APP_PATH/biblioteca/${1}.bd && echo "Alta ejecutada correctamente." # introduce el id del alta, (la primera vez falla porque no hay numeros, se redirige el error para que no se muestre i automaticamente se pone el 1 al sumarlo) i tambien introduce los campos
                pulsa_enter
                pedir_campos=0
            else
                echo "Campos incorrectos."
                pulsa_enter
            fi
        done
        ;;
        "prestamos")
            still=1
            for i in $(echo ${!2} | tr "," " "); do  # itera sobre los campos
                while [ $still -eq 1 ]; do
                    echo -e "${i#*_}s:\n" # se convierte por ejemplo id_libro(campo) a libros(se le quita *_ y se añade una s al final)
                    filee="${i#*_}s"
                    cat $APP_PATH/biblioteca/$filee.bd | column -t -s ","  # facilidad para elegir
                    echo
                    read -p "Introducce el $i: " value
                    if [[ $(cat $APP_PATH/biblioteca/$filee.bd | cut -d"," -f1 | grep -w $value | wc -l) -ne 0 ]];then  # mira si existe en la bd
                        still=0
                        data_prestamo+=",$value" # si existe, se añade a los datos a añadir
                    else
                        echo "El id: $value no existe en la base de datos de $filee."
                    fi
                done
                still=1
            done

            local user=$(echo $data_prestamo | cut -d"," -f3)
            local libro=$(echo $data_prestamo | cut -d"," -f2)
            # se pone que el libro ha sido prestado, se suma 1 al num_prestads del usuario y se añade el prestamo, si algo falla el resto no se ejecutara
            alta_libro_prestado $libro && sumar_libro_usuario $user && echo $(($(tail $APP_PATH/biblioteca/$1.bd -n1 2> /dev/null | cut -d"," -f1)+1))$data_prestamo >> $APP_PATH/biblioteca/${1}.bd && echo "Alta ejecutada correctamente." 
            data_prestamo=""
        ;;
    esac
    
}
sumar_libro_usuario(){
    # se le incrementa el numero de libros al usuario
    # las tres siguientes funciones funcionan igual que esta pero cambiando el signo
    local linea_user=$(grep "^$1" $APP_PATH/biblioteca/usuarios.bd)
    local nueva_linea=$(echo $linea_user | awk -F, '{$6+=1}1' OFS=,) # nueva liniea con el num_prestados actualizado
    if [ $(echo $linea_user | cut -d"," -f6) -eq 3 ];then
        echo "Este usuario no puede recoger mas libros, ya tiene 3 prestamos."
        return 1
    else
        sed -i "s/$linea_user/$nueva_linea/g" /home/jordi/biblioteca/usuarios.bd # se actualiza la linea, 
    fi
    
}

alta_libro_prestado(){
    # se actualiza el estado del libro a prestado
    if [[ $(grep "^$1" $APP_PATH/biblioteca/libros.bd | cut -d"," -f7) -eq 1 ]];then
        echo "El libro ya ha sido prestado."
        return 1
    else
        local linea_lib=$(grep "^$1" $APP_PATH/biblioteca/libros.bd)
        local nueva_linea=$(echo $linea_lib | awk -F, '{$7+=1}1' OFS=,)
        
        sed -i "s/$linea_lib/$nueva_linea/g" /home/jordi/biblioteca/libros.bd
    fi
}

baja_libro_prestado(){
     # se actualiza el estado del libro a disponible
    if [[ $(grep "^$1" $APP_PATH/biblioteca/libros.bd | cut -d"," -f7) -eq 0 ]];then
        echo "El libro no ha sido prestado."
        return 1
    else
        local linea_lib=$(grep "^$1" $APP_PATH/biblioteca/libros.bd)
        local nueva_linea=$(echo $linea_lib | awk -F, '{$7-=1}1' OFS=,)

        if [[ $(echo $nueva_linea | cut -d"," -f7) -lt 0 ]];then
            nueva_linea=$(echo $linea_lib | awk -F, '{$7=0}1' OFS=,)
        fi
        
        sed -i "s/$linea_lib/$nueva_linea/g" /home/jordi/biblioteca/libros.bd
    fi
}
restar_libro_usuario(){
    # se le disminuye el numero de libros al usuario
    local linea_user=$(grep "^$1" $APP_PATH/biblioteca/usuarios.bd)
    local nueva_linea=$(echo $linea_user | awk -F, '{$6-=1}1' OFS=,)

    if [ $(echo $linea_user | cut -d"," -f6) -eq 0 ];then
        echo "Este usuario no tiene ningun prestamo."
        return 1
    else
        sed -i "s/$linea_user/$nueva_linea/g" /home/jordi/biblioteca/usuarios.bd
    fi
    
}
baja() {
    # se da de baja la opcion seleccionada
    comprobar_si_ficheros_existen
    read -p "ID del elemento que se quiere borrar: " id_del

    case "$1" in
        "libros"|"usuarios")
            if [[ $(cat $APP_PATH/biblioteca/$1.bd | cut -d"," -f1 | grep -w $id_del | wc -l) -ne 0 ]];then # se comprueba si existe
            # TODO: si hay prestamos pendientes, no se puede dar de baja usuario ni libros
                elimina_linea_fichero $1 $id_del  # borra la linea
            else
                echo "No existe este ${1:0:${#1}-1} en la base de datos."
            fi
        ;;
        "prestamos")
            local user=$(grep "^$id_del" $APP_PATH/biblioteca/$1.bd | cut -d"," -f3)
            local lib=$(grep "^$id_del" $APP_PATH/biblioteca/$1.bd | cut -d"," -f2)

            if [[ $(grep "^$id_del" $APP_PATH/biblioteca/libros.bd | wc -l) -gt 0 ]];then
                # si existe, se disminuye el numero de libros del user, se actualiza el estado del libro a disponible y se borra de prestamos
                baja_libro_prestado $lib && restar_libro_usuario $user && elimina_linea_fichero $1 $id_del
            else
                echo "No existe ese prestamo."
            fi
        ;;
    esac

}

consulta(){
# se hace una consulta sobre la opcion elegida de qualquiera de sus campos   
    generar_submenu $2  # genera menu de las opciones disponibles

    read -p "Numero del campo por el que desea buscar: " op_field

    read -p "Que desea buscar en el campo '${arr_campos[$op_field-1]}'" to_search

    ((op_field++)) # se incrementa porque en el archivo esta el id, pero aqui no se muestra
    echo "Resultado:"
    echo -e ${!2} | column -t -s ","  # se imprime los nombres de los campos
    cad=$(cat $APP_PATH/biblioteca/$1.bd | cut -d"," -f$op_field | grep $to_search) # se utiliza la opcion elegida para buscar el campo
    # awk -F "," -v cad="$cad" -v num_col="$op_field" '{ if ($num_col == cad) { print $0} }' $APP_PATH/biblioteca/$1.bd # si el parametro buscado coincide, se imprime la linea

    cat $APP_PATH/biblioteca/$1.bd | while read line
    do
        if [[ $(echo $line | cut -d"," -f$op_field | grep $to_search | wc -l) -gt 0 ]];then
            echo $line | column -t -s "," # se van imprimiendo los registros que coincidan
        fi
    done
    pulsa_enter
}

listado(){
    # se listan los prestamos
    echo "LISTADO DE PRESTAMOS"
    cat $APP_PATH/biblioteca/$1.bd | column -t -s ","
    pulsa_enter
}

generar_submenu(){
    # se genera un submenu diferente dependiendo de la opcion elegida
    arr_campos=($(echo ${!1} | tr "," " "))
    local cont=1
    
    echo "BUSCAR POR:"
    for i in ${arr_campos[@]}; do
        echo "$cont.$i"
        ((cont++))
    done  
}

elimina_linea_fichero() {
    # elimina un registro
    # se obtiene la linea, despues el numero que ocupa en el fichero de bd y por ultimo se borra
    linea=$(cat $APP_PATH/biblioteca/$1.bd | grep "^$2")
    num_linea=$(cat -n $APP_PATH/biblioteca/$1.bd | grep "$linea" | cut -d$'\t' -f1 | tr -d '[:space:]')
    sed -i "${num_linea}d" $APP_PATH/biblioteca/$1.bd # elimina la linea i machaca el archivo
    echo "Baja ejecutada corrrectamente"
}

comprobar_si_ficheros_existen() {
    # comprueba si la estructura existe, si no la crea
    if [[ ! -d $APP_PATH/biblioteca ]];then
        echo "No se detecta la estructura de la base de datos, creando..."
        mkdir $APP_PATH/biblioteca
    fi
}

input_invalido(){
    # simple echo, para no redundar tanto codigo
    echo "Elige una opcion valida."
    pulsa_enter
}
function pulsa_enter() {
    # texto que parpadea para dar visibilidad al script
    echo -e "\033[5mENTER para continuar.\033[0m"
    read
}

# MAIN
while [ $end -eq 0 ]; do
    welcome
    end=$?
done
