#!/bin/bash

. $2

designation=$1

function promoteSlave(){

    $this_pg_path/pg_ctl -D $this_data_path promote

    $this_pg_path/psql postgres -c "CHECKPOINT" -p $this_port

}

function changeConfigurationsFor(){

echo "PRIMARY_HOST=$SECONDARY_HOST
PRIMARY_PORT=$SECONDARY_PORT
PRIMARY_PG_PATH=$SECONDARY_PG_PATH
PRIMARY_DATA_PATH=$SECONDARY_DATA_PATH
PRIMARY_RECOVERY_FILE=$SECONDARY_RECOVERY_FILE
PRIMARY_CONF_FILE=$SECONDARY_CONF_FILE
PRIMARY_LOG_FILE=$SECONDARY_LOG_FILE
PRIMARY_FOS_FILE=$SECONDARY_FOS_FILE
PRIMARY_FOS_PID_FILE=$SECONDARY_FOS_PID_FILE
PRIMARY_FOS_CONF_FILE=$SECONDARY_FOS_CONF_FILE
PRIMARY_FOS_LOG_FILE=$SECONDARY_FOS_LOG_FILE
SECONDARY_HOST=$PRIMARY_HOST
SECONDARY_PORT=$PRIMARY_PORT
SECONDARY_PG_PATH=$PRIMARY_PG_PATH
SECONDARY_RECOVERY_FILE=$PRIMARY_RECOVERY_FILE
SECONDARY_LOG_FILE=$PRIMARY_LOG_FILE
SECONDARY_CONF_FILE=$PRIMARY_CONF_FILE
SECONDARY_DATA_PATH=$PRIMARY_DATA_PATH
SECONDARY_FOS_FILE=$PRIMARY_FOS_FILE
SECONDARY_FOS_PID_FILE=$PRIMARY_FOS_PID_FILE
SECONDARY_FOS_CONF_FILE=$PRIMARY_FOS_CONF_FILE
SECONDARY_FOS_LOG_FILE=$PRIMARY_FOS_LOG_FILE" | ssh $1 "cat > $2"

echo "---------------------------------->  changed configurations in the folder @$1 $2"

}

function changeConfigurations(){

designation=Primary  
echo "---------------------------------->  changed Designation to Primary"

changeConfigurationsFor $this_host $this_fos_conf_file
changeConfigurationsFor $another_host $another_fos_conf_file

echo "---------------------------------->  Configuartion Changes Completed"

}

function pg_rewind_func(){

    ssh $another_host "

    $another_pg_path/pg_ctl -D $another_data_path -l $another_log_file start

    $another_pg_path/pg_ctl -D $another_data_path -l $another_log_file stop

    $another_pg_path/pg_rewind --target-pgdata=$another_data_path --source-server=\"port=$this_port host=$this_host user=$USER dbname=postgres\" --progress
    
    touch $another_data_path/recovery.conf

    cat $another_recovery_file > $another_data_path/recovery.conf

    sed -i /\"port = \"/d  $another_data_path/postgresql.conf 
    echo \"port = $another_port\" >> $another_data_path/postgresql.conf

    $another_pg_path/pg_ctl -D $another_data_path -l $another_log_file start"

    setsid -f ssh $another_host "$another_fos_file Secondary $another_fos_conf_file 1>$another_fos_log_file" ####################################


}

function get_fos_pid(){

    value=$(ssh $another_host "grep fosPid $another_fosPid_file|cut -d'=' -f2") 

    another_fos_pid=$(ssh localhost "ps aux | grep $value|grep -v grep| awk '{print $2}'" |awk '{print $2}')
    
}

function get_postgres_pid(){
    
    postgres_pid=$(lsof -i:$1 | grep postgres -m 1|awk '{print $2}')

}

if [ $designation = Secondary ];then
    this_host=$SECONDARY_HOST
    this_port=$SECONDARY_PORT
    this_pg_path=$SECONDARY_PG_PATH
    this_data_path=$SECONDARY_DATA_PATH
    this_conf_file=$SECONDARY_CONF_FILE
    this_recovery_file=$SECONDARY_RECOVERY_FILE
    this_log_file=$SECONDARY_LOG_FILE
    this_fos_file=$SECONDARY_FOS_FILE
    this_fosPid_file=$SECONDARY_FOS_PID_FILE
    this_fos_conf_file=$SECONDARY_FOS_CONF_FILE
    this_fos_log_file=$SECONDARY_FOS_LOG_FILE
    another_host=$PRIMARY_HOST
    another_port=$PRIMARY_PORT
    another_pg_path=$PRIMARY_PG_PATH
    another_data_path=$PRIMARY_DATA_PATH
    another_conf_file=$PRIMARY_CONF_FILE
    another_recovery_file=$PRIMARY_RECOVERY_FILE
    another_log_file=$PRIMARY_LOG_FILE
    another_fos_file=$PRIMARY_FOS_FILE
    another_fosPid_file=$PRIMARY_FOS_PID_FILE
    another_fos_conf_file=$PRIMARY_FOS_CONF_FILE
    another_fos_log_file=$PRIMARY_FOS_LOG_FILE
elif [ $designation = Primary ];then
    this_host=$PRIMARY_HOST
    this_port=$PRIMARY_PORT
    this_pg_path=$PRIMARY_PG_PATH
    this_data_path=$PRIMARY_DATA_PATH
    this_conf_file=$PRIMARY_CONF_FILE
    this_recovery_file=$PRIMARY_RECOVERY_FILE
    this_log_file=$PRIMARY_LOG_FILE
    this_fos_file=$PRIMARY_FOS_FILE
    this_fosPid_file=$PRIMARY_FOS_PID_FILE
    this_fos_conf_file=$PRIMARY_FOS_CONF_FILE
    this_fos_log_file=$PRIMARY_FOS_LOG_FILE
    another_host=$SECONDARY_HOST
    another_port=$SECONDARY_PORT
    another_pg_path=$SECONDARY_PG_PATH
    another_data_path=$SECONDARY_DATA_PATH
    another_conf_file=$SECONDARY_CONF_FILE
    another_recovery_file=$SECONDARY_RECOVERY_FILE
    another_log_file=$SECONDARY_LOG_FILE
    another_fos_file=$SECONDARY_FOS_FILE
    another_fosPid_file=$SECONDARY_FOS_PID_FILE
    another_fos_conf_file=$SECONDARY_FOS_CONF_FILE
    another_fos_log_file=$SECONDARY_FOS_LOG_FILE
else
    echo "Please start by Primary or Secondary"
    exit 0
fi

echo "fosPid=$BASHPID" > $this_fosPid_file

while [ true ];do
    
    get_postgres_pid $this_port

    pid=$postgres_pid

    declare -i count

    count=3

    while [[ -z $pid && count -lt 3 ]];do
        get_postgres_pid $this_port

        pid=$postgres_pid

        echo "----------------------------------> Trying to start postgres :Count:$count"

        pg_ctl -D $this_pg_path -l $this_log_file start

        count=count+1

    done

    if [ $pid ];then

        if [ $designation = Secondary ];then

            get_fos_pid

            if [ -z $another_fos_pid ];then

                promoteSlave
                changeConfigurations
                pg_rewind_func

            fi 
        fi

    else
        echo "---------------------------------->  Failed To start the Server At Port $this_port: Aborting FOS" 
        exit 0
    fi
    
    if [ $designation = Secondary ];then
        echo "---------------------------------->  Fos running For Secondary mode"
    else
        echo "---------------------------------->  Fos running For Primary mode"
    fi
    sleep 5
done

