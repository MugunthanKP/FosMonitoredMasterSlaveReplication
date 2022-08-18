#! /bin/bash

filename=$1

while [ true ]
do
    if [ -n $filename ]
    then 
        break
    else
        echo -n "Enter a single file name"
        read filename
    fi
done
while [ true ]
do
    if [ -f $filename.sh ]
    then
        echo "$filename already exits"
        echo -n "Enter another name "
        read filename
    else
        touch $filename.sh
        chmod +x $filename.sh
        echo "#!/bin/bash" >> $filename.sh
        code $filename.sh
        break
    fi
done

