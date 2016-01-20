#!/bin/sh
# vSphere 5.x ESXi
# Script create-vm:
# Creación de una nueva VM con características mínimas desde cero en cli
# Ene/2016

#Directorio donde se ubicará la maquina
DATASTOREPATH=/vmfs/volumes/datastore25/av019

vm_list() { echo "Estas son las maquinas registradas en este servidor:"
            vim-cmd vmsvc/getallvms
           } #Una funcion para listar las maquinas registradas

# MEJORA 1 Imprimir su uso
if [ $# -eq 0 ]; then
	echo "Uso: $0 <NEW_VM_NAME> [MV_TYPE] [MV_DISK_SIZE_IN_MB] [MV_NUM_NT]"
	exit 1
else
	# Nombre de la máquina virtual
	MV_NAME=$1

	# Tipo de la maquina virtual
	if [ -z "$2" ]; then
		MV_TYPE="other"
	else
		MV_TYPE=$2
	fi

	# Tamaño de disco
	if [ -z "$3" ]; then
		MV_SIZE=1
	else
		MV_SIZE=$3
	fi
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

#Comprobar si existe una maquina con el mismo nombre
if ( exist_vm $MV_NAME )
then
    echo Una vm con nombre \'$MV_NAME\' no existe
    vm_list
    exit 3
fi


#Crear la nueva máquina (sugerencia: usar vim-cmd vmsvc/createdummyvm)
vim-cmd vmsvc/createdummyvm $MV_NAME $DATASTOREPATH

# MEJORA 3
if ( ! test -z "$3" )
then 
	vmkfstools -X "${MV_SIZE}MB" $DATASTOREPATH/$MV_NAME/$MV_NAME.vmdk -d eagerzeroedthick
fi


#Listar todas las máquinas para comprobar que se ha creado
vm_list

#Hay que añadir al fichero de configuración (.vmx) algún(os) campo(s) que es(son) imprescindible(S) para arrancar la máquina
#Sugerencia: intenta arrancar la máquina una vez creada y busca en el fichero 
#            wmware.log por qué ha fallado el arranque

# MEJORA 2
seddelete guestOS $DATASTOREPATH/$MV_NAME/$MV_NAME.vmx
echo "guestOS = \"$MV_TYPE\"" >> $DATASTOREPATH/$MV_NAME/$MV_NAME.vmx


#Para terminar arranca el clon desde el cliente de vSphere

