#! /bin/bash

# Set the NCM home directory
if [ -z $szHomeDir ]; then
    . /home/netcommon/config/netcommonrc
fi

# Set the NCM working variables
szLogFile="$szLogDir/undefined.log"
szLogDay="$(date +%Y%m%d)"
szJsonLogFile="/tmp/json.log"

# Load the configuration files
if [ -f $szConfigDir/netcommon.sh ]; then
    . $szConfigDir/netcommon.sh
fi
if [ -f $szConfigDir/users.sh ]; then
    . $szConfigDir/users.sh
fi
if [ -f $szConfigDir/zabbix-params.sh ]; then
    . $szConfigDir/zabbix-params.sh
else
    . $szBaseTmplDir/zabbix-params.sh
fi

# Load the internal utils
. $szBinDir/utils-mysql.sh
. $szBinDir/utils-json.sh
. $szBinDir/utils-dbforbix.sh

# Set the internal variables
szBatchMode="n"
if [ -z "$szMailFrom" ]; then
    szMailFrom="send-hook . \"my_hdr From: $szCliente <ncm@netcomgroup.eu>\""
fi


function clear_spaces()
{
    local szOut

    szOut=$(echo "$1" | sed -e 's/^ *//g' -e 's/ *$//g')
    echo "$szOut"
}

function clear_quotes()
{
    local szOut

    szOut=$(echo "$1" | sed -e 's/^"//'  -e 's/"$//')
    echo "$szOut"
}

function change_spaces()
{
    local szOut

    szOut=$(echo "$1" | sed -e 's/ /$2/')
    echo "$szOut"
}

function set_batch_mode()
{
    szBatchMode="s"
    out_message "    Modo batch attivato."
}

function is_batch_mode()
{
    echo $szBatchMode
}

function pause()
{
    local szRead=""

    if [ -z "$1" ]; then
        read -e -p "Premi enter per continuare: " szRead < /dev/tty
    else
        read -e -p "$1: " szRead < /dev/tty
    fi
}

#******************************************************************************
#
#     I N P U T     F U N C T I O N S
#
#******************************************************************************
function read_variable()
{
    local szRead=""
    local szIsValid=""


    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            read -e -p "$1 [$2]: " szRead < /dev/tty
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi
        case "$szRead" in  
        *\ * )
            out_message "    La stringa non puo' contenere spazi ($szRead)."
            szBatchMode="a"
            szRead="";;
        * )
            if [ ! -z "$szRead" ]; then
                szIsValid="y"
            else
                out_message "    La stringa non puo' essere vuota."
                szBatchMode="a"
            fi;;
        esac
    done              

    echo "$szRead"
}

function read_variable_noslash()
{
    local szRead=""
    local szIsValid=""


    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            read -e -p "$1 [$2]: " szRead < /dev/tty
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi
        case "$szRead" in  
        *\ * )
            out_message "    La stringa non puo' contenere spazi ($szRead)."
            szBatchMode="a"
            szRead="";;
        */* )
            out_message "    La stringa non puo' contenere slash ($szRead)."
            szBatchMode="a"
            szRead="";;
        * )
            if [ ! -z "$szRead" ]; then
                szIsValid="y"
            else
                out_message "    La stringa non puo' essere vuota."
                szBatchMode="a"
            fi;;
        esac
    done              

    echo "$szRead"
}

function read_variable_null()
{
    local szRead=""
    local szIsValid=""

    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            read -e -p "$1 (opzionale) [$2]: " szRead < /dev/tty
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi
        case "$szRead" in  
        *\ * )
            out_message "    La stringa non puo' contenere spazi ($szRead)."
            szBatchMode="a"
            szRead="";;
        * )
            szIsValid="y";;
        esac
    done              

    echo "$szRead"
}

function read_string()
{
    local szRead=""
    local szIsValid=""

    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            read -e -p "$1 [$2]: " szRead < /dev/tty
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi
        if [ ! -z "$szRead" ]; then
            szIsValid="y"
        else
            out_message "    La stringa non puo' essere vuota."
            szBatchMode="a"
        fi
    done              

    echo "$szRead"
}

function read_string_null()
{
    local szRead=""
    local szIsValid=""

    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            read -e -p "$1 (opzionale) [$2]: " szRead < /dev/tty
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi
        szIsValid="y"
    done              

    echo "$szRead"
}

function read_yes_no()
{
    local szRead=""

    while [ -z "$szRead" ]; do
        szRead=$(read_variable "$1" "$2")
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        case "$szRead" in  
        s | n )
            szIsValid="y";;
        * )
            out_message "    Risposta non valida ($szRead). Scegli fra s/n."
            szRead="";;
        esac
    done              

    echo "$szRead"
}

function read_ip_address()
{
    local szRead=""
    local szIP1="",szIP2="",szIP3="",szIP4=""

    while [ -z "$szRead" ]; do
        szRead=$(read_variable "$1" "$2")
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        szIP1=$(echo $szRead | awk -F "." '{print $1}')
        szIP2=$(echo $szRead | awk -F "." '{print $2}')
        szIP3=$(echo $szRead | awk -F "." '{print $3}')
        szIP4=$(echo $szRead | awk -F "." '{print $4}')

        if [[ -z "$szIP1" || -z "$szIP2" || -z "$szIP3" || -z "$szIP4" ]]; then
            out_message "    Indirizzo IP non valido ($szRead)."
            szRead=""
        fi
    done              

    echo "$szRead"
}

function read_ip_address_null()
{
    local szRead=""
    local szIsValid=""
    local szIP1="",szIP2="",szIP3="",szIP4=""

    while [ -z "$szIsValid" ]; do
        szIsValid=""
        if [ $szBatchMode != "s" ]; then
            szRead=$(read_variable_null "$1" "$2")
        else
            szRead=$2
        fi
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        if [ ! -z "$szRead" ]; then
            szIP1=$(echo $szRead | awk -F "." '{print $1}')
            szIP2=$(echo $szRead | awk -F "." '{print $2}')
            szIP3=$(echo $szRead | awk -F "." '{print $3}')
            szIP4=$(echo $szRead | awk -F "." '{print $4}')

            if [[ -z "$szIP1" || -z "$szIP2" || -z "$szIP3" || -z "$szIP4" ]]; then
                out_message "    Indirizzo IP non valido ($szRead)."
                szBatchMode="a"
                szRead=""
            else
                szIsValid="y"
            fi
        else
            szIsValid="y"
        fi
    done              

    echo "$szRead"
}

function read_switch_type()
{
    local szRead=""

    while [ -z "$szRead" ]; do
        szRead=$(read_variable "$1" "$2")
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        case "$szRead" in  
        ProCurve )
            szIsValid="y";;
        * )
            out_message "    Tipo switch non valido ($szRead). Scegli fra: ProCurve."
        esac
    done              

    echo "$szRead"
}

function read_host_type()
{
    local szRead=""

    while [ -z "$szRead" ]; do
        szRead=$(read_variable "$1" "$2")
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        case "$szRead" in  
        Windows | Linux | Solaris | AIX | HPUX )
            szIsValid="y";;
        * )
            out_message "    Tipo server non valido ($szRead): scegli fra Windows, Linux, Solaris, AIX, HPUX."
        esac
    done              

    echo "$szRead"
}

function read_mail()
{
    local szRead=""
    local szUser="",szDomain=""

    while [ -z "$szRead" ]; do
        szRead=$(read_variable "$1" "$2")
        if [ -z "$szRead" ]; then
            szRead=$2
        fi

        szUser=$(echo $szRead | awk -F "@" '{print $1}')
        szDomain=$(echo $szRead | awk -F "@" '{print $2}')

        if [[ -z "$szUser" || -z "$szDomain" ]]; then
            out_message "    Indirizzo mail non valido ($szRead)."
            szRead=""
        fi
    done              

    echo "$szRead"
}

function change_param()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"
    local szMyValue=""

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla change_param ($szName,$szValue,$szFile)."
        exit
    fi

    # Sostituisci gli slash
    szMyValue=$(echo $szValue | sed 's/\//\\\//g')
    
    # out_message "    SED: $szName-$szMyValue-$szFile."
    sed -i "s/<$szName>/$szMyValue/g" "$szFile"
}

function remove_param()
{
    local szName="$1"
    local szFile="$2"

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla remove_param ($szName,$szFile)."
        exit
    fi

    # out_message "    SED: $szName-$szFile."
    sed -i "/<$szName>/d" "$szFile"
}

function change_string()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla change_string ($szName,$szValue,$szFile)"
        exit
    fi

    sed -i "s/$szName/$szValue/g" "$szFile"
}

function add_row()
{
    local szMatch="$1"
    local szValue="$2"
    local szFile="$3"

    # out_message "    add_row ($szMatch,$szValue,$szFile)"
    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla add_row ($szMatch,$szValue,$szFile)"
        exit
    fi

    currLine=$(cat "$szFile" | awk "/$szMatch/{ print NR; exit }")
    if [ ! -z "$currLine" ]; then
        nextLine=`expr $currLine + 1 `
        sed -i "$nextLine i\ $szValue" "$szFile"
    fi
}

function read_dom_next_token()
{
    local IFS=\>

    szContent=""
    read -d \< szEntity szContent
}

function parse_xml()
{
    local szXmlFile="$1"
    local szOutFile="$2"
    local szCurrPath=""
    local szReduced=""
    local szInitial=""
    local szFinal=""

    rm -f $szOutFile

    while read_dom_next_token; do
        szContent=$(echo $szContent | tr -d '\n' | sed 's/[ \t]*$//')
        if [ ! -z "$szContent" ]; then
            printf "%s/%s@%s\n" "$szCurrPath" "$szEntity" "$szContent" >> $szOutFile
        fi
        szReduced="n"
        szInitial=$(echo $szEntity | head -c1)
        if [[ ! -z $szInitial && $szInitial == "/" ]]; then
            szCurrPath=$(echo $szCurrPath | rev | cut -d'/' -f2- | rev)
            szReduced="s"
            # echo "    <<< $szCurrPath ($szInitial)" >> $szOutFile
        fi
        if [ ! -z "$szEntity" ]; then
            szFinal=${szEntity:${#szEntity} - 1}
            if [[ ! -z $szFinal && $szFinal == "/" ]]; then
                szReduced="s"
                # echo "    >>><<< $szCurrPath ($szInitial)" >> $szOutFile
            fi
        fi
        if [[ $szReduced == "n" && ! -z $szInitial && $szInitial != "?" ]]; then
            szFinal=${szCurrPath:${#szCurrPath} - 1}
            if [[ ! -z $szFinal && $szFinal == "/" ]]; then
                szCurrPath=$szCurrPath$szEntity
            else
                szCurrPath=$szCurrPath/$szEntity
            fi
            # echo "    >>> $szCurrPath ($szInitial)" >> $szOutFile
        fi
    done < $szXmlFile
}

function get_params_from_xml()
{
    local szTmpFile="/tmp/get_params_from_xml.tmp"
    local szParsedFile="$1"
    local szOutFile="$2"
    local iParamCount=$3
    local iCount=1

    # Inizializza l'array di parametri con valori non validi per egrep
    for (( i = 1; i <= 32; i++ )); do
        szParam[$i]="This is an invalid value: don't change me"
    done

    # Leggi i nomi dei parametri da estrarre dal file
    for (( i = 1, p = 4; i <= $iParamCount; i++, p++ )); do
        szParam[$i]=$(echo ${@:$p:1})
    done

    # Azzera i file temporanei
    rm -f $szTmpFile
    rm -f $szOutFile

    # Legge i parametri richiesti dal file
    grep -e "${szParam[1]}" -e "${szParam[2]}" -e "${szParam[3]}" -e "${szParam[4]}" -e "${szParam[5]}" -e "${szParam[6]}" -e "${szParam[7]}" -e "${szParam[8]}" -e "${szParam[9]}" -e "${szParam[10]}" $szParsedFile >> $szTmpFile

    # Crea il file contenente i parametri richiesti in forma tabellare
    while read line; do
        szName=$(echo $line | awk -F "@" '{print $1}')
        szValue=$(echo $line | awk -F "@" '{print $2}')
        if [ "$iCount" -lt "$iParamCount" ]; then
            printf "%s@" $szValue >> $szOutFile
            let iCount++
        else
            printf "%s\n" $szValue >> $szOutFile
            iCount=1
        fi
    done < $szTmpFile
}

###############################################################################
#
#     F U N Z I O N I     D I     O U T P U T
#
###############################################################################
function log_start()
{
    local szTmp=""
    local szName=""
    local szLogTime="$(date +%d/%m/%Y-%H:%M:%S)"

    # szTmp="$(basename $0 .sh)"
    # szName=$(echo $szTmp | awk -F "." '{print $1}')
    szName=$(basename $0 .sh)
    szLogFile="$szLogDir/$szName.$szLogDay.log"
    printf "\n%s: start *******************************************\n" "$szLogTime" >> $szLogFile
}

function log_end()
{
    local szLogTime="$(date +%d/%m/%Y-%H:%M:%S)"

    printf "%s: end *********************************************\n" "$szLogTime" >> $szLogFile
}

function log_message()
{
    printf "%s\n" "$1" >> $szLogFile
}

function out_message()
{
    printf "%s\n" "$1" >> /dev/stderr
}

function out_error()
{
    printf "*** ERRORE: %s\n" "$1" >> /dev/stderr
}

function dbg_message()
{
    printf "%s\n" "$1" >> /dev/stderr
}

function json_message()
{
    myTmp=$(echo "$1" | grep '\*\*\*')
    if [ ! -z "$myTmp" ]; then
        printf "\n" >> $szJsonLogFile
    fi 
    printf "%s\n" "$1" >> $szJsonLogFile
}

###############################################################################
#
#     A P P L I C A T I O N
#
###############################################################################
function json_application_check()
{
    local szType="$1"
    local szLowerType=""
    local szSuiteName=""
    local szApplicationName=""
    local szModuleName=""
    local szRet=""

    # Controlla se il tipo di applicazione e' gestito
    case "$szType" in  
    SUITE.APP ) ;;
    Generic ) ;;
    * )
        out_error "applicazione $szType non gestita. I valori possibili sono:"
        out_message "    SUITE.APP"
        out_message "    Generic"
        exit -1
        ;;
    esac

    # Estrai le componenti del nome dell'applicazione
    szLowerType=$(echo $szType | awk '{print tolower($0)}')
    szSuiteName=$(echo $szLowerType | awk -F "." '{print $1}')
    szApplicationName=$(echo $szLowerType | awk -F "." '{print $2}')
    szModuleName=$(echo $szLowerType | awk -F "." '{print $3}')

    # Controlla se il file di template esiste
    if [ ! -f $szXmlTmplDir/template.application.$szLowerType.xml ]; then
        out_error "template file per l'applicazione $szType non trovato."
        exit -1
    fi
}

function json_schema_check()
{
    local szType="$1"
    local szLowerType=""
    local szSuiteName=""
    local szApplicationName=""
    local szRet=""

    # Controlla se il tipo di schema e' gestito
    case "$szType" in  
    SUITE.APP ) ;;
    Generic ) ;;
    * )
        out_error "schema $szType non gestito. I valori possibili sono:"
        out_message "    SUITE.APP"
        out_message "    Generic"
        exit -1
        ;;
    esac

    # Estrai le componenti del nome dello schema
    szLowerType=$(echo $szType | awk '{print tolower($0)}')
    szSuiteName=$(echo $szLowerType | awk -F "." '{print $1}')
    szApplicationName=$(echo $szLowerType | awk -F "." '{print $2}')

    # Controlla se il file di template esiste
    if [ ! -f $szXmlTmplDir/template.schema.$szLowerType.xml ]; then
        if [ ! -f $szXmlTmplDir/template.schema.$szLowerType.meas.xml ]; then
            if [ ! -f $szXmlTmplDir/template.schema.$szLowerType.moni.xml ]; then
                out_error "template file per lo schema $szType non trovato."
                exit -1
            fi
        fi
    fi
}
