#!/bin/sh
# vSphere 5.x ESXi
# Script linked-clone:
# Creación de un linked clone de una VM existente en cli
# Ene/2016

#Recuerda!:
# ESTO DEBE SER UN FICHERO TEXTO UNIX (NO MSDOS)
# DEBE TENER PERMISO DE EJECUCION (chmod +x fichero)

#Directorio donde se ubican las máquinas
#Sustituir por el directorio de trabajo en cada caso
DATASTOREPATH=/vmfs/volumes/datastore25/av019

vm_list() { echo "Estas son las maquinas registradas en este servidor:"
            vim-cmd vmsvc/getallvms
           } #Una funcion para listar las maquinas registradas

funfile=`dirname $0`/script_functions.sh
if ( ! test -f $funfile )
then
	echo "No se encuentra script_functions.sh"
	exit 2
else
	#Incluir funciones
	. $funfile
fi

#Imprimir su uso
if [ $# -eq 0 ]; then
	echo "Uso: $0 <EXISTING_VM_NAME> <CLON_VM_NAME>"
	exit 1
else
	# Nombre de la máquina virtual existente
	EXISTING_VM_NAME=$1
	# Nombre de la máquina virtual clon
	CLON_VM_NAME=$2
	# ID de la máquina virtual existente
	VMID=$(get_vmid $EXISTING_VM_NAME)
fi

#Encontrar la ubicación e identificadores de la máquina a copiar


#Comprobar que existe la máquina origen a clonar
if ( ! exist_vm $EXISTING_VM_NAME )
then
    echo Una vm con nombre \'$EXISTING_VM_NAME\' no existe
    vm_list
    exit 3
fi



#Comprobar que no existe la maquina clon
if ( exist_vm $CLON_VM_NAME )
then
    echo Una vm con nombre \'$CLON_VM_NAME\' no existe
    vm_list
    exit 5
fi

# Comprobamos que la maquina esta endencida y la apagamos
if ( vim-cmd vmsvc/power.getstate $VMID | grep on > /dev/null )
then
    vim-cmd vmsvc/power.off $VMID
fi



#Comprobar que la máquina origen tiene uno y sólo un snapshot
snaps=$(count_snapshots $VMID)
if [ "$snaps" -ne 1 ]
then
	echo 'La máquina virtual tiene que tener uno y sólo un snapshot'
	vim-cmd vmsvc/snapshot.create $VMID "SnapShot" "Snap generated" 1 1
	echo 'SnapShot creado'
fi



#Copiar los ficheros de definición de la máquina origen a la máquina clon:
# - fichero de configuración: .vmx,
# - fichero de definición del disco: .vmdk
# - fichero delta del snapshot
# Nota: es necesario averiguar los nombres de estos ficheros 
#       a partir del fichero de configuración

# Crear un snapshot
# vim-cmd vmsvc/snapshot.create 3 "ReferenceSnapshot" "Usado por linked clones"

mkdir $DATASTOREPATH/$CLON_VM_NAME

# Copiamos el fichero .vmx
VMXGUEST=$(get_vm_vmx $VMID)
cp $DATASTOREPATH/$EXISTING_VM_NAME/$VMXGUEST $DATASTOREPATH/$CLON_VM_NAME

# Copiamos el fichero .vmdk y el delta del snapshot
VMDKGUEST=$(get_value 'scsi.*fileName' $DATASTOREPATH/$EXISTING_VM_NAME/$VMXGUEST)
filename="${VMDKGUEST%.*}"
cp $DATASTOREPATH/$EXISTING_VM_NAME/$filename*.vmdk $DATASTOREPATH/$CLON_VM_NAME



#Sustituir los nombres de ficheros y sus respectivas referencias dentro de
#estos por el nombre clon 
#¡Atención! Esto requiere un pequeño parsing del contenido 
#para sustituir aquellos campos de los ficheros de configuración que hacen 
#referencias a los ficheros.
mv $DATASTOREPATH/$CLON_VM_NAME/*-delta.vmdk $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME-delta.vmdk
mv $DATASTOREPATH/$CLON_VM_NAME/$filename.vmdk $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmdk
mv $DATASTOREPATH/$CLON_VM_NAME/*.vmx $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx

seddelete sched.swap.derivedName $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
seddelete uuid.location $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
seddelete uuid.bios $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
seddelete ethernet0.generatedAddress $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
seddelete extendedConfigFile $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx

seddelete displayName $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
seddelete scsi0:0.fileName $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
echo "displayName = $CLON_VM_NAME" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
echo "scsi0:0.fileName = $CLON_VM_NAME.vmdk" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx



#Cambiar la referencia del “parent disk” del fichero de definición del disco
#que debe de apuntar al de la máquina origen (en el directorio ..)
seddelete parentFileNameHint $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx
echo "parentFileNameHint = $DATASTOREPATH/$EXISTING_VM_NAME/$EXISTING_VM_NAME.vmdk" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx



#Generar un fichero .vmsd (con nombre del clon) en el que se indica que
#es una máquina clonada.
#
#Coge un fichero .vmsd de un clon generado con VMware Workstation para ver
#el formato de este archivo
#
#Si no se genera el fichero .vmsd, al destruir el clon también se borra el
#disco base del snapshot, lo cual no es deseable ya que pertenece a la máquina 
#origen



touch $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmsd
echo ".encoding = \"UTF-8\"" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmsd
echo "snapshot.lastUID = \"$(get_value 'snapshot.lastUID' $DATASTOREPATH/$EXISTING_VM_NAME/$EXISTING_VM_NAME.vmsd)\"" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmsd
echo "snapshot.mru0.uid = \"$(get_value 'snapshot.mru0.uid' $DATASTOREPATH/$EXISTING_VM_NAME/$EXISTING_VM_NAME.vmsd)\"" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmsd
echo "snapshot.mru1.uid = \"$(get_value 'snapshot.mru1.uid' $DATASTOREPATH/$EXISTING_VM_NAME/$EXISTING_VM_NAME.vmsd)\"" >> $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmsd


#Una vez que el directorio clon contiene todos los ficheros necesarios
#hay que registrar la máquina clon (ESTO ES IMPRESCINDIBLE)
vim-cmd solo/registervm $DATASTOREPATH/$CLON_VM_NAME/$CLON_VM_NAME.vmx


#Listar todas las máquinas para comprobar que el clon está disponible
vm_list


#Para terminar arranca el clon desde el cliente de vSphere
CLONE_ID=$(get_vmid $CLON_VM_NAME)
vim-cmd vmsvc/power.on $CLONE_ID & | vim-cmd vmsvc/message $CLONE_ID _vmx2 2 | vim-cmd vmsvc/power.off $CLONE_ID

