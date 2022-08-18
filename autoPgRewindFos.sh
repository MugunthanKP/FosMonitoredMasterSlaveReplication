#!/bin/bash

. ./fos.conf

designation=$1

function promoteSlave(){

    pg_ctl -D $this_pg_path promote

    psql postgres -c "CHECKPOINT" -p $this_port

}

function changeConfigurations(){

designation=Primary

echo "primary_port=$secondary_port
primary_pg_path=$secondary_pg_path
primary_recovery_file=$secondary_recovery_file
primary_conf_file=$secondary_conf_file
primary_log_file=$secondary_log_file
primary_fosPid_file=$secondary_fosPid_file
secondary_port=$primary_port
secondary_recovery_file=$primary_recovery_file
secondary_log_file=$primary_log_file
secondary_conf_file=$primary_conf_file
secondary_pg_path=$primary_pg_path
secondary_fosPid_file=$primary_fosPid_file" > fos.conf


}

function pg_rewind_func(){

    pg_ctl -D $another_pg_path -l $another_log_file start

    pg_ctl -D $another_pg_path -l $another_log_file stop

    pg_rewind --target-pgdata=$another_pg_path --source-server="port=$this_port user=$USER dbname=postgres" --progress
    touch $another_pg_path/recovery.conf
    
    while IFS='=' read key value;do
        sed -i /"$key = "/d  $another_pg_path/recovery.conf
        echo "$key = $value" >> $another_pg_path/recovery.conf
    done < $another_recovery_file

    sed -i /"port = "/d  $another_pg_path/postgresql.conf 
    echo "port = $another_port" >> $another_pg_path/postgresql.conf

    pg_ctl -D $another_pg_path -l $another_log_file start

    setsid -f ./autoPgRewindFos.sh Secondary 1>newSecondary.txt
    
}

function get_fos_pid(){

    local value=$(grep fosPid $another_fosPid_file|cut -d'=' -f2) 
    local another_fos_pid=$(ps aux|grep $value| grep -v grep| cut -d' ' -f2)

    echo $another_fos_pid

    
}

function get_postgres_pid(){
    
    local postgres_pid=$(lsof -t -i:$1 | grep "" -m 1)
    # Check whether it is postgres

    echo $postgres_pid
}

if [ $designation = Secondary ];then
    this_port=$secondary_port
    this_pg_path=$secondary_pg_path
    this_conf_file=$secondary_conf_file
    this_recovery_file=$secondary_recovery_file
    this_log_file=$secondary_log_file
    this_fosPid_file=$secondary_fosPid_file
    another_port=$primary_port
    another_pg_path=$primary_pg_path
    another_conf_file=$primary_conf_file
    another_recovery_file=$primary_recovery_file
    another_log_file=$primary_log_file
    another_fosPid_file=$primary_fosPid_file
else
    this_port=$primary_port
    this_pg_path=$primary_pg_path
    this_conf_file=$primary_conf_file
    this_recovery_file=$primary_recovery_file
    this_log_file=$primary_log_file
    this_fosPid_file=$primary_fosPid_file
    another_por1814641t=$secondary_port
    another_pg_path=$secondary_pg_path
    another_conf_file=$secondary_conf_file
    another_recovery_file=$secondary_recovery_file
    another_log_file=$secondary_log_file
    another_fosPid_file=$secondary_fosPid_file
fi

echo "fosPid=$BASHPID" > $this_pg_path/fosPid.txt

while [ true ];do

    pid=$(get_postgres_pid $this_port)

    declare -i count

    count=3

    while [[ -z $pid && count -lt 3 ]];do

        pid=$(get_postgres_pid $this_port)

        echo "starting postgres"
        pg_ctl -D $this_pg_path -l $this_log_file start

        count=count+1

    done

    if [ $pid ];then

        if [ $designation = Secondary ];then

            another_fos_pid=$(get_fos_pid)

            if [ -z $another_fos_pid ];then

                echo "promoting slave"
                promoteSlave
                echo "changing configurations secondary to primary"
                changeConfigurations
                echo "rewinding old primary"
                pg_rewind_func
                echo "rewinding finished"

            fi 
        fi

    else
        break
    fi
    
    if [ $designation = Secondary ];then
        echo "fos running for secondary mode"
    else
        echo "fos running for primary mode"
    fi
    sleep 5
done

