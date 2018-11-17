#! /bin/bash


#******************************************************************************
#
#     G E N E R I C
#
#******************************************************************************
function jisql_get_dbforbix_parameter()
{
    local szDSN="$1"
    local szName="$2"
    local szDatabaseConfig="$szConfigDir/dbforbix.database/config.props"
    local szSchemaConfig="$szConfigDir/dbforbix.schema/config.props"
    local szLine=""
    local szValue=""

    # out_message "^$szDSN.$szName"
    szLine=$(grep "^$szDSN.$szName" "$szDatabaseConfig")
    if [ ! -z "$szLine" ]; then
        # szValue=$(echo "$szLine" | awk -F "=" '{$1=""; print $0}')
        szValue=$(echo "$szLine" | awk -F "$szName=" '{print $2}')
    else
        szLine=$(grep "^$szDSN.$szName" "$szSchemaConfig")
        if [ ! -z "$szLine" ]; then
            # szValue=$(echo "$szLine" | awk -F "=" '{$1=""; print $0}')
            szValue=$(echo "$szLine" | awk -F "$szName=" '{print $2}')
        fi
    fi

    szValue=$(clear_spaces "$szValue")
    if [ -z "$szValue" ]; then
        out_error "DSN $szDSN.$szName non trovato."
    fi

    echo "$szValue"
}

function jisql_execute_script()
{
    local szDSN="$1"
    local szScriptFile="$2"

    # Leggi i dati per la connessione 
    szConnect=$(jisql_get_dbforbix_parameter "$szDSN" "Url")
    szUsername=$(jisql_get_dbforbix_parameter "$szDSN" "User")
    szPassword=$(jisql_get_dbforbix_parameter "$szDSN" "Password")
    # out_message "$szConnect $szUsername:$szPassword"

    # Esegui lo statement SQL
    myCmd="java -cp $szLibDir/jisql-2.0.11.jar:$szLibDir/ojdbc6.jar com.xigole.util.sql.Jisql -driver oraclethin -cstring "\""$szConnect"\"" -u $szUsername -p $szPassword -c "\"";"\"" -noheader -left -input "\""$szScriptFile"\"""
    # out_message "$myCmd"
    szRet=$(eval "$myCmd")
    echo "$szRet"
}

function jisql_execute_sql()
{
    local szDSN="$1"
    local szSQL="$2"
    local szRet=""

    # Leggi i dati per la connessione 
    szConnect=$(jisql_get_dbforbix_parameter "$szDSN" "Url")
    szUsername=$(jisql_get_dbforbix_parameter "$szDSN" "User")
    szPassword=$(jisql_get_dbforbix_parameter "$szDSN" "Password")
    # out_message "Connect:$szConnect username:$szUsername password:$szPassword"

    # Se i dati di connessione sono stati trovati...
    if [ ! -z "$szConnect" ]; then

        # Esegui lo statement SQL
        myCmd="java -cp $szLibDir/jisql-2.0.11.jar:$szLibDir/ojdbc6.jar com.xigole.util.sql.Jisql -driver oraclethin -cstring "\""$szConnect"\"" -u $szUsername -p $szPassword -c "\"";"\"" -noheader -left -query "\""$szSQL"\"""
        # out_message "$myCmd"
        szRet=$(eval "$myCmd")
    fi

    # Ritorna l'output del comando, se eseguito
    echo "$szRet"
}

#******************************************************************************
#
#     O R A C L E
#
#******************************************************************************
function jisql_oracle_discovery_tablespaces()
{
    local szDSN="$1"
    local szSQL="select distinct tablespace_name from dba_data_files where tablespace_name not like 'UNDO%';"

    # Esegui lo statement SQL
    myCmd=$(jisql_execute_sql "$szDSN" "$szSQL")
    echo "$myCmd"
}

function jisql_oracle_discovery_diskgroups()
{
    local szDSN="$1"
    local szSQL="select distinct name from v\\\$asm_diskgroup;"

    # Esegui lo statement SQL
    myCmd=$(jisql_execute_sql "$szDSN" "$szSQL")
    echo "$myCmd"
}
