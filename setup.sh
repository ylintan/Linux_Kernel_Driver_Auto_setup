#!/bin/bash

KERN_SRC_TAG=Ubuntu-intel-5.11.0-1012.14

KERN_MOD_DIR=/lib/modules/$(uname -r)/kernel/drivers
BUS_DIR=drivers/bus
NET_DIR=drivers/net

_FILE=drivers/net/mhi/proto_mbim.c

mkdir -p SE30_SOP_Quec
cd SE30_SOP_Quec

# Down the SRC
url=https://git.launchpad.net/~canonical-kernel/ubuntu/+source/linux-intel/+git/focal/plain
tag=$KERN_SRC_TAG
files="
include/linux/mhi.h \
include/linux/wwan.h \
drivers/bus/mhi/Makefile \
drivers/bus/mhi/Kconfig \
drivers/bus/mhi/pci_generic.c \
drivers/bus/mhi/core/Makefile \
drivers/bus/mhi/core/boot.c \
drivers/bus/mhi/core/debugfs.c \
drivers/bus/mhi/core/init.c \
drivers/bus/mhi/core/internal.h \
drivers/bus/mhi/core/main.c \
drivers/bus/mhi/core/pm.c \
drivers/net/wwan/Kconfig \
drivers/net/wwan/Makefile \
drivers/net/wwan/mhi_wwan_ctrl.c \
drivers/net/wwan/wwan_core.c \
drivers/net/mhi/proto_mbim.c \
drivers/net/mhi/net.c \
drivers/net/mhi/mhi.h \
drivers/net/mhi/Makefile
"
mkdir -p drivers/net/wwan
mkdir -p drivers/net/mhi
mkdir -p drivers/bus/mhi/core
mkdir -p include/linux
mkdir -p include/uapi/linux

for f in ${files}
do
   rm -rf ${f}
   wget ${url}/${f}?h=${tag} -O ${f} --no-check-certificate
done

# Change the Code.
if [ -e "${_FILE}" ]; then
LINE_NUM=`sed -n '/#define MHI_MBIM_DEFAULT_MRU 3500/=' ${_FILE}`
sed -i "${LINE_NUM}s/3500/32768/g" ${_FILE}
else
echo "Code is not valid!"
exit
fi

# Generate the Makefile.
touch Makefile

echo -e 'ifeq ($(KERNELRELEASE),) \n'\
'PWD := $(shell pwd) \n'\
'ifeq ($(ARCH),) \n'\
'ARCH := $(shell uname -m) \n'\
'endif \n'\
'ifeq ($(CROSS_COMPILE),) \n'\
'CROSS_COMPILE := \n'\
'endif \n'\
'ifeq ($(KDIR),) \n'\
'KDIR := /lib/modules/$(shell uname -r)/build \n'\
'endif \n\n'\
'default: \n'\
'	$(MAKE) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -C $(KDIR) M=$(PWD) modules \n\n'\
'clean: \n'\
'	$(MAKE) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -C $(KDIR) M=$(PWD) clean \n'\
'endif \n\n'\
'obj-m+=drivers/bus/mhi/ \n'\
'obj-m+=drivers/net/wwan/ \n'\
'obj-m+=drivers/net/mhi/' > Makefile

# Compile 
make

if [ $? -eq 0 ]
then
echo "Compile succeded!"
else
echo "Compile failed, please check the build log!"
fi

# Install the kernel object.

cp $NET_DIR/mhi/mhi_net.ko $KERN_MOD_DIR/net/mhi/mhi_net.ko

if [ $? -eq 0 ]
then
echo ""
else
echo "No effective kernel object found, please check your code!"
exit
fi
#cp $BUS_DIR/mhi/mhi_pci_generic.ko $KERN_MOD_DIR/$BUS_DIR/mhi/mhi_pci_generic.ko
#cp $BUS_DIR/mhi/core/mhi.ko $KERN_MOD_DIR/$BUS_DIR/mhi/core/mhi.ko
#cp $NET_DIR/wwan/mhi_wwan_ctrl.ko $KERN_MOD_DIR/$NET_DIR/wwan/mhi_wwan_ctrl.ko
#cp $NET_DIR/wwan/wwan.ko $KERN_MOD_DIR/$NET_DIR/wwan/wwan.ko


# Make the changes become effective.
depmod -ae > /dev/null 2>&1
update-initramfs -u > /dev/null 2>&1

echo "Update Successfully!"
