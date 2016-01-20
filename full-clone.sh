#!/bin/sh
# vSphere 5.x ESXi
#Script 7.2:
#Creación de un full clone de una VM existente en cli
#Ene/2016

#Recuerda!:
# ESTO DEBE SER UN FICHERO TEXTO UNIX (NO MSDOS)
# DEBE TENER PERMISO DE EJECUCION (chmod +x fichero)

#Directorio donde se ubican las máquinas
#Sustituir por el directorio de trabajo en cada caso
DATASTOREPATH=/vmfs/volumes/datastore25/av019

#Imprimir su uso
if ( test $# -gt 1 )
then
    SOURCE_NAME=$1
    CLONE_NAME=$2
else
    echo Uso: $0 source_vm_name clone_name
    exit 1
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

#Encontrar la ubicación e identificadores de la máquina a copiar
SOURCE_ID=$(get_vmid $SOURCE_NAME)
if ( vim-cmd vmsvc/power.getstate $SOURCE_ID | grep on > /dev/null )
then
    vim-cmd vmsvc/power.off $SOURCE_ID
fi

#Comprobar que existe la máquina origen a clonar
if ( ! exist_vm $SOURCE_NAME )
then
    echo Una vm con nombre \'$SOURCE_NAME\' no existe
    vm_list
    exit 3
fi

#Comprobar que no existe la maquina clon
if ( exist_vm $CLONE_NAME )
then
    echo La vm con nombre \'$CLONE_NAME\' ya existe
    exit 4
fi

#Copiar recursivamente el directorio de la máquina origen a su destino (clon)
echo "Realizando el full clone de la máquina $SOURCE_NAME"
cp -r "$DATASTOREPATH/$SOURCE_NAME/" "$DATASTOREPATH/$CLONE_NAME"
mv "$DATASTOREPATH/$CLONE_NAME/$SOURCE_NAME.vmx" "$DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx"
mv "$DATASTOREPATH/$CLONE_NAME/$SOURCE_NAME.vmdk" "$DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmdk"

seddelete sched.swap.derivedName $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
seddelete uuid.location $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
seddelete uuid.bios $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
seddelete extendedConfigFile $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
seddelete scsi0:0.fileName $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
seddelete nvram $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx

seddelete displayName $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
echo "displayName = \"$CLONE_NAME\"" >> $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
echo "scsi0:0.fileName = \"$CLONE_NAME.vmdk\"" >> $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
echo "extendedConfigFile = \"$CLONE_NAME.vmxf\"" >> $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
echo "nvram = \"$CLONE_NAME.nvram\"" >> $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx
#Registar la máquina clon (ESTO ES IMPRESCINDIBLE)
vim-cmd solo/registervm $DATASTOREPATH/$CLONE_NAME/$CLONE_NAME.vmx

CLONE_ID=$(get_vmid $CLONE_NAME)

#Listar todas las máquinas para comprobar que el clon está disponible
if ( ! exist_vm $VM_NAME )
then
    echo "Ups, ha habido un error al crear el clon."
    exit 5
fi

#Para terminar arranca el clon desde el cliente de vSphere
