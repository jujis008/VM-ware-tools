#!/bin/sh
# vSphere 5.x ESXi
# Script delete-vm:
# Borrado de una VM existente en cli
# Ene/2016

#Directorio donde se ubican las máquinas
#Sustituir por el directorio de trabajo en cada caso
DATASTOREPATH=/vmfs/volumes/datastore25/av019

vm_list() { echo "Estas son las maquinas registradas en este servidor:"
            vim-cmd vmsvc/getallvms
           } #Una funcion para listar las maquinas registradas

#Imprimir su uso
if ( ! test $# -eq 1 ) 
then
	echo "Este script requiere uno y solo un argumento (nombre de la vm)"
    vm_list
	exit 1
else
    VM_NAME=$1
fi

#Incluir funciones que se proporcionan
funfile=`dirname $0`/script_functions.sh
if ( ! test -f $funfile )
then
	echo "No se encuentra script_functions.sh"
	exit 2
else
	#Incluir funciones
	. $funfile
fi

#Comprobar si existe la máquina en cuestión
if ( ! exist_vm $VM_NAME )
then
    echo Una vm con nombre \'$VM_NAME\' no existe
    vm_list
    exit 3
fi

#Solicitar confirmación de borrado
read -p "Seguro que quieres eliminar la maquina $VM_NAME? [y/n]" -n 1 -r
if [ ! "$REPLY" = "y" ]
then
    echo
    exit 4
fi

#Apagar la máquina
# Conseguimos el id de la vm
VM_ID=$(get_vmid $VM_NAME)
# Apagamos solo si estaba encendida previamente
if ( vim-cmd vmsvc/power.getstate $VM_ID | grep on > /dev/null )
then
    vim-cmd vmsvc/power.off $VM_ID
fi

#Borrar la máquina (sugerencia: usar vim-cmd vmsvc/destroy)
echo "Borrando la maquina virtual ..."
vim-cmd vmsvc/destroy $VM_ID 

#Listar todas las máquinas para comprobar que se ha borrado
if ( exist_vm $VM_NAME )
then
    echo "Ups, la maquina no pudo ser eliminada."
    exit 5
else
    echo "Maquina borrada correctamente."
    exit 0
fi
