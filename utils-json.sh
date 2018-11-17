#! /bin/bash

szAuth="not_connected"
szAddress="127.0.0.1"
#szAddress=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
if [ ! -z "$szCurlUseProxy" ]; then
    szCurlCmd="curl -s -X POST -H 'Content-Type:application/json' http://$szAddress/zabbix/api_jsonrpc.php -d @"
else
    szCurlCmd="curl --noproxy $szAddress -s -X POST -H 'Content-Type:application/json' http://$szAddress/zabbix/api_jsonrpc.php -d @"
fi
szDebug="s"

. $szBinDir/utils-json-action.sh
. $szBinDir/utils-json-host.sh
. $szBinDir/utils-json-refresh.sh
. $szBinDir/utils-json-template.sh
. $szBinDir/utils-json-user.sh
. $szBinDir/utils-json-web.sh

###############################################################################
#
#     G E N E R A L
#
###############################################################################
function json_enable_debug()
{
    szDebug="s"
}

function json_change_param()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"
    local szMyValue=""

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla json_change_param ($szName,$szValue,$szFile)"
        exit
    fi

    # Applica le seguenti modifiche al valore:
    #    sostituisci gli slash
    #    sostituisci gli ampersand
    #    rimuovi le virgolette iniziali e finali
    szMyValue=$(echo "$szValue" | sed 's/\//\\\//g' | sed -e 's/&/\\&/g' | sed -e 's/^"//' -e 's/"$//')
    # out_message "$szName: $szValue, $szMyValue."
    sed -i "s/<$szName>/""$szMyValue""/g" "$szFile"
}

function json_change_xml()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"
    local szMyValue=""

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla json_change_xml ($szName,$szValue,$szFile)"
        exit
    fi

    # Applica le seguenti modifiche al valore:
    #    sostituisci i backslash
    #    sostituisci gli slash
    #    sostituisci gli ampersand
    #    rimuovi le virgolette iniziali e finali
    szMyValue=$(echo "$szValue" | sed 's/\\/\\\\/g' | sed 's/\//\\\//g' | sed -e 's/&/\\&/g' | sed -e 's/^"//' -e 's/"$//')
    sed -i "s/<$szName>/$szMyValue/g" "$szFile"
}

function json_change_param_from_file()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla json_change_param_from_file ($szName,$szValue,$szFile)"
        exit
    fi

    sed -i "/<$szName>/r $szValue" "$szFile"
    sed -i "/<$szName>/d" "$szFile"
}

function xml_change_param()
{
    local szName="$1"
    local szValue="$2"
    local szFile="$3"
    local szMyValue=""

    if [ -z "$szFile" ]; then
        out_error "mancano parametri alla xml_change_param ($szName,$szValue,$szFile)"
        exit
    fi

    # Applica le seguenti modifiche al valore:
    #    sostituisci gli slash
    #    sostituisci gli ampersand
    #    rimuovi le virgolette iniziali e finali
    szMyValue=$(echo "$szValue" | sed 's/\//\\\//g' | sed -e 's/&/\\&/g' | sed -e 's/^"//' -e 's/"$//')
    # out_message "$szName: $szValue, $szMyValue."
    sed -i "s/<$szName>/""$szMyValue""/g" "$szFile"
}

function json_compact()
{
    local szFile="$1"
    local szOut

    # Rimuovi i newline e gli spazi duplicati
    szOut=$(cat "$szFile" | tr -d '\n' | sed "s/ \+</</g")
    # json_message "    json_compact: $szOut"

    echo "$szOut"
}

function json_set_auth()
{
    if [[ "$1" != -* ]]; then
        szAuth="$1"
    else
        out_message "Stringa di autorizzazione ignorata (copy da batch script?)"
        set_batch_mode
    fi
}

function json_list_to_json()
{
    local szList="$1"
    local szJsonList=""

    szJsonList=$(echo "[$szList]" | sed 's/" "/","/g')

    echo $szJsonList
}

function json_connect()
{
    local tmpFile="/tmp/user.login.json"
    local szRet

    if [ $szAuth != "not_connected" ]; then
        echo $szAuth
        return
    fi

    rm -f $szJsonLogFile
    json_message "*****json_connect()"

    cp -f $szJsonTmplDir/user.login.json $tmpFile
    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    user.login: $szRet"
    fi

    szMyAuth=$(echo "$szRet" | jshon -Q -e "result" -e "sessionid")
    echo $szMyAuth
}

###############################################################################
#
#     C O N F I G U R A T I O N
#
###############################################################################
function update_item_frequencies()
{
    local tmpFile="$1"

    # Aggiorna le frequenze di scansione
    json_change_xml timConfig "$timConfig" $tmpFile
    json_change_xml timDbFast "$timDbFast" $tmpFile
    json_change_xml timDbMedium "$timDbMedium" $tmpFile
    json_change_xml timDbSlow "$timDbSlow" $tmpFile
    json_change_xml timDiscovery "$timDiscovery" $tmpFile
    json_change_xml timInterface "$timInterface" $tmpFile
    json_change_xml timJmxFast "$timJmxFast" $tmpFile
    json_change_xml timJmxMedium "$timJmxMedium" $tmpFile
    json_change_xml timJmxSlow "$timJmxSlow" $tmpFile
    json_change_xml timLogFile "$timLogFile" $tmpFile
    json_change_xml timPort "$timPort" $tmpFile
    json_change_xml timProcInfo "$timProcInfo" $tmpFile
    json_change_xml timProcStatus "$timProcStatus" $tmpFile
    json_change_xml timStats "$timStats" $tmpFile
    json_change_xml timSystemFast "$timSystemFast" $tmpFile
    json_change_xml timSystemMedium "$timSystemMedium" $tmpFile
    json_change_xml timSystemSlow "$timSystemSlow" $tmpFile
}

function json_configuration_import()
{
    local szRet
    local szXmlFile="$1"
    local szXML
    local szResult
    local tmpFile="/tmp/configuration.import.json"

    json_message "*****json_configuration_import($szXmlFile)"
    if [[ "$szXmlFile" == /tmp/templates/* ]]; then
        json_change_xml timConfig "$timConfig" "$szXmlFile"
        json_change_xml timDbFast "$timDbFast" "$szXmlFile"
        json_change_xml timDbMedium "$timDbMedium" "$szXmlFile"
        json_change_xml timDbSlow "$timDbSlow" "$szXmlFile"
        json_change_xml timDiscovery "$timDiscovery" "$szXmlFile"
        json_change_xml timInterface "$timInterface" "$szXmlFile"
        json_change_xml timJmxFast "$timJmxFast" "$szXmlFile"
        json_change_xml timJmxMedium "$timJmxMedium" "$szXmlFile"
        json_change_xml timJmxSlow "$timJmxSlow" "$szXmlFile"
        json_change_xml timLogFile "$timLogFile" "$szXmlFile"
        json_change_xml timPort "$timPort" "$szXmlFile"
        json_change_xml timProcInfo "$timProcInfo" "$szXmlFile"
        json_change_xml timProcStatus "$timProcStatus" "$szXmlFile"
        json_change_xml timStats "$timStats" "$szXmlFile"
        json_change_xml timSystemFast "$timSystemFast" "$szXmlFile"
        json_change_xml timSystemMedium "$timSystemMedium" "$szXmlFile"
        json_change_xml timSystemSlow "$timSystemSlow" "$szXmlFile"
    fi
    szXML=$(json_compact "$szXmlFile")

    cp -f $szJsonTmplDir/configuration.import.json $tmpFile
    json_change_param szAuth $szAuth $tmpFile
    json_change_xml szXML "$szXML" $tmpFile 

    # Aggiorna le frequenze di scansione
    json_change_xml timConfig "$timConfig" $tmpFile
    json_change_xml timDbFast "$timDbFast" $tmpFile
    json_change_xml timDbMedium "$timDbMedium" $tmpFile
    json_change_xml timDbSlow "$timDbSlow" $tmpFile
    json_change_xml timDiscovery "$timDiscovery" $tmpFile
    json_change_xml timInterface "$timInterface" $tmpFile
    json_change_xml timJmxFast "$timJmxFast" $tmpFile
    json_change_xml timJmxMedium "$timJmxMedium" $tmpFile
    json_change_xml timJmxSlow "$timJmxSlow" $tmpFile
    json_change_xml timLogFile "$timLogFile" $tmpFile
    json_change_xml timPort "$timPort" $tmpFile
    json_change_xml timProcInfo "$timProcInfo" $tmpFile
    json_change_xml timProcStatus "$timProcStatus" $tmpFile
    json_change_xml timStats "$timStats" $tmpFile
    json_change_xml timSystemFast "$timSystemFast" $tmpFile
    json_change_xml timSystemMedium "$timSystemMedium" $tmpFile
    json_change_xml timSystemSlow "$timSystemSlow" $tmpFile

    # Importa il file
    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    configuration.import ($myCmd): $szRet"
    fi

    if [ ! -z "$szRet" ]; then
        szResult=$(echo "$szRet" | jshon -Q -e "result")
        if [ -z $szResult ]; then
            szResult="false"
        fi
    else
        szResult="true"
    fi
    echo $szResult
}

###############################################################################
#
#     A P P L I C A T I O N
#
###############################################################################
function json_application_get_id()
{
    local tmpFile="/tmp/host.getappid.json"
    local szRet
    local szHostId="$1"
    local szAppName="$2"
    local szAppId=""

    json_message "*****json_application_get_id($szHostId,$szAppName)"

    cp -f $szJsonTmplDir/application.get.json $tmpFile
    json_change_param szAuth $szAuth $tmpFile
    json_change_param szHostId "$szHostId" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    application.getid: $szRet"
    fi

    iCount=$(echo $szRet | grep -o "applicationid" | wc -l)
    for (( i = 0; i < $iCount; i++ )); do
        szId=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "applicationid")
        szName=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "name")
        szName=$(clear_quotes "$szName")
        if [ "$szName" == "$szAppName" ]; then
            szAppId=$(clear_quotes "$szId")
        fi
    done

    echo $szAppId
}

###############################################################################
#
#     S C R E E N
#
###############################################################################
function json_screen_exists()
{
    local tmpFile="/tmp/screen.exists.json"
    local szRet
    local szName=$1
    local szFound

    json_message "*****json_screen_exists($szName)"
    cp -f $szJsonTmplDir/screen.get.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szName "$szName" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    screen.exists: $szRet"
    fi

    szFound=$(echo "$szRet" | jshon -Q -e "result" -e 0)
    if [ -z "$szFound" ]; then
        szRet="false"
    else
        szRet="true"
    fi
    echo $szRet
}

function json_screen_getid()
{
    local tmpFile="/tmp/screen.get.json"
    local szRet
    local szName=$1
    local szId

    json_message "*****json_screen_getid($szName)"
    cp -f $szJsonTmplDir/screen.get.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szName "$szName" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    screen.get: $szRet"
    fi

    szId=$(echo "$szRet" | jshon -Q -e "result" -e 0 -e "screenid")
    echo $szId
}

function json_screen_list()
{
    local tmpFile="/tmp/screen.list.json"
    local szRet
    local szId
    local szResult
    local i

    json_message "*****json_screen_list()"
    cp -f $szJsonTmplDir/screen.list.json $tmpFile
    json_change_param szAuth $szAuth $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    screen.list: $szRet"
    fi

    cat /dev/null > /tmp/array.tmp
    iCount=$(echo $szRet | grep -o "screenid" | wc -l)
    for (( i = 0; i < $iCount; i++ )); do
        szId=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "screenid")
        szName=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "name")
        case "$szName" in
        \"Zabbix*\")
            # out_message "Skipping $szName..."
            :
            ;;
        *)
            # out_message "Adding $szName..."
            echo "$szId;""$szName" >> /tmp/array.tmp
            # echo "$szId" >> /tmp/array.tmp
            ;;
        esac
    done
    sort /tmp/array.tmp | uniq > /tmp/sortedarray.tmp

    #while read line; do           
    #    szResult=$(echo "$szResult" "$line")
    #done < /tmp/sortedarray.tmp

    #echo "$szResult"
    cat /tmp/sortedarray.tmp
}

function json_screen_delete()
{
    local tmpFile="/tmp/screen.delete.json"
    local szRet
    local szScreenId=$1
    local szResult

    json_message "*****json_screen_delete($szScreenId)"
    cp -f $szJsonTmplDir/screen.delete.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szScreenId "$szScreenId" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    screen.delete: $szRet"
    fi

    szResult=$(echo "$szRet" | jshon -Q -e "result" -e "screenids" -e 0)
    if [ ! -z $szResult ]; then
        szResult="true"
    else
        szResult="false"
    fi
    echo $szResult
}

function json_screen_create()
{
    local szFound
    local szScreenName="$1"
    local szType="$2"
    local szResult
    local szRet
    local tmpXmlDir="/tmp/templates/screens/$szScreenName"
    local tmpXmlFile="$tmpXmlDir/screen.create.xml"

    json_message "*****json_screen_create($szScreenName, $szType)"
    # Importa lo screen, se non esistente
    szFound=$(json_screen_exists "$szScreenName")
    if [ $szFound == "false" ]; then

        if [ -f $szXmlTmplDir/template.screen-$szType.xml ]; then
            mkdir -p "$tmpXmlDir"
            cp -f $szXmlTmplDir/template.screen-$szType.xml "$tmpXmlFile"
            xml_change_param szScreenName "$szScreenName" "$tmpXmlFile"
            for (( i = 1; i <= 18; i++)); do
                iIndex=$(expr $i + 2)
                szParam=$(echo ${@:$iIndex:1})
                szHostName=$(echo "$szParam" | awk -F ":" '{print $1}')
                szServiceName=$(echo "$szParam" | awk -F ":" '{print $2}')
                xml_change_param szHostName$i "$szHostName" "$tmpXmlFile"
                xml_change_param szServiceName$i "$szServiceName" "$tmpXmlFile"
            done

            szResult=$(json_configuration_import "$tmpXmlFile")
            if [ $szResult != "true" ]; then
                out_error "errore nella importazione dello screen $szName."
            fi
        else
            out_error "screen template template.screen-$szType.xml non trovato."
        fi
    fi

    szId=$(json_screen_getid "$szScreenName")
    echo $szId
}

###############################################################################
#
#     D I S C O V E R Y     R U L E
#
###############################################################################
function json_drule_exists()
{
    local tmpFile="/tmp/drule.exists.json"
    local szRet
    local szName=$1
    local szFound

    json_message "*****json_drule_exists($szName)"
    cp -f $szJsonTmplDir/drule.getid.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szName "$szName" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    drule.exists: $szRet"
    fi

    szFound=$(echo "$szRet" | jshon -Q -e "result" -e 0)
    if [ -z "$szFound" ]; then
        szRet="false"
    else
        szRet="true"
    fi
    echo $szRet
}

function json_drule_getid()
{
    local szName="$1"
    local tmpFile="/tmp/drule.getid.json"
    local szRet
    local szId

    json_message "*****json_drule_getid($szRuleName)"
    cp -f $szJsonTmplDir/drule.getid.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szName "$szName" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    drule.get: $szRet"
    fi

    szId=$(echo "$szRet" | jshon -Q -e "result" -e 0 -e "druleid")
    echo $szId
}

function json_drule_list()
{
    local tmpFile="/tmp/drule.list.json"
    local szRet
    local szId
    local szResult
    local i

    json_message "*****json_drule_list()"
    cp -f $szJsonTmplDir/drule.list.json $tmpFile
    json_change_param szAuth $szAuth $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    drule.list: $szRet"
    fi

    cat /dev/null > /tmp/array.tmp
    iCount=100
    for (( i = 0; i < $iCount; i++ )); do
        szId=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "druleid")
        szName=$(echo "$szRet" | jshon -Q -e "result" -e $i -e "name")
        case "$szName" in
        \"NCM* )
            # out_message "Adding $szName..."
            echo "$szId;""$szName" >> /tmp/array.tmp
            # echo "$szId" >> /tmp/array.tmp
            ;;
        esac
    done
    sort /tmp/array.tmp | uniq > /tmp/sortedarray.tmp

    #while read line; do           
    #    szResult=$(echo "$szResult" "$line")
    #done < /tmp/sortedarray.tmp

    #echo "$szResult"
    cat /tmp/sortedarray.tmp
}

function json_drule_delete()
{
    local tmpFile="/tmp/drule.delete.json"
    local szRet
    local szDruleId=$1
    local szResult

    json_message "*****json_drule_delete($szDruleId)"
    cp -f $szJsonTmplDir/drule.delete.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szDruleId "$szDruleId" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    drule.delete: $szRet"
    fi

    szResult=$(echo "$szRet" | jshon -Q -e "result" -e "druleids" -e 0)
    if [ ! -z $szResult ]; then
        szResult="true"
    else
        szResult="false"
    fi
    echo $szResult
}

function json_drule_create()
{
    local szRuleName="$1"
    local szType="$2"
    local szHostList="$3"
    local tmpFile="/tmp/drule.$szType.create.json"
    local szRet
    local szId

    json_message "*****json_drule_create($szRuleName, $szType, $szHostList)"
    # Crea la discovery rule, se non esistente
    szFound=$(json_drule_exists "$szRuleName")
    if [ $szFound == "false" ]; then

        cp -f $szJsonTmplDir/drule.$szType.create.json $tmpFile

        json_change_param szAuth $szAuth $tmpFile
        json_change_param szRuleName "$szRuleName" $tmpFile
        json_change_param szHostList "$szHostList" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
        if [ $szDebug == "s" ]; then
            json_message "    drule.$szType.create: $szRet"
        fi
    fi

    szId=$(json_drule_getid "$szRuleName")
    echo $szId
}

###############################################################################
#
#     M A P S
#
###############################################################################
function json_map_initialize()
{
    local szMapId="$1"
    local myElementsFile=$(change_spaces "/tmp/map.$szMapId.elements.json" "_")

    json_message "*****json_map_initialize($szMapId)"
    rm -f $myElementsFile
}

function json_map_add_element()
{
    local szMapId="$1"
    local szHostId="$2"
    local szIconId="$3"
    local szX="$4"
    local szY="$5"
    local myElementsFile=$(change_spaces "/tmp/map.$szMapId.elements.json" "_")
    local szRet
    local szId

    json_message "*****json_map_add_element($szMapId, $szHostId, $szIconId, $szX, $szY)"
    if [ -f $myElementsFile ]; then
        printf ",\n" >> $myElementsFile
    fi
    cat $szJsonTmplDir/map.element.json >> $myElementsFile

    json_change_param szHostId "$szHostId" $myElementsFile
    json_change_param szIconId "$szIconId" $myElementsFile
    json_change_param szX "$szX" $myElementsFile
    json_change_param szY "$szY" $myElementsFile
}

function json_map_create()
{
    local szMapId="$1"
    local szMapName="$2"
    local tmpFile="/tmp/map.create.json"
    local myElementsFile=$(change_spaces "/tmp/map.$szMapId.elements.json" "_")
    local szRet
    local szId

    json_message "*****json_map_create($szMapId, $myMapName)"
    cp -f $szJsonTmplDir/map.create.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szMapId "$szMapId" $tmpFile
    json_change_param szMapName "$szMapName" $tmpFile
    json_change_param_from_file szElements $myElementsFile $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    map.create: $szRet"
    fi

    szId=$(echo "$szRet" | jshon -Q -e "result" -e "sysmapids" -e 0)
    echo $szId
}

function json_map_update()
{
    local szMapId="$1"
    local szMapName="$2"
    local tmpFile="/tmp/map.update.json"
    local myElementsFile=$(change_spaces "/tmp/map.$szMapId.elements.json" "_")
    local szRet
    local szId

    json_message "*****json_map_update($szMapId, $szMapName)"
    cp -f $szJsonTmplDir/map.update.json $tmpFile

    szMapId=$(json_map_getid "$szMapName")

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szMapId "$szMapId" $tmpFile
    json_change_param szMapName "$szMapName" $tmpFile
    json_change_param_from_file szElements $myElementsFile $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    map.update: $szRet"
    fi

    szId=$(echo "$szRet" | jshon -Q -e "result" -e "sysmapids" -e 0)
    echo $szId
}

function json_map_getid()
{
    local tmpFile="/tmp/map.get.json"
    local szRet
    local szMapName=$1
    local szMapId

    json_message "*****json_map_getid($szMapName)"
    cp -f $szJsonTmplDir/map.get.json $tmpFile

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szMapName "$szMapName" $tmpFile

    myCmd="$szCurlCmd$tmpFile"; szRet=$(eval "$myCmd")
    if [ $szDebug == "s" ]; then
        json_message "    map.get: $szRet"
    fi

    szMapId=$(echo "$szRet" | jshon -Q -e "result" -e 0 -e "sysmapid")
    echo $szMapId
}

###############################################################################
#
#     G R A P H S
#
###############################################################################
function json_graph_get()
{
    local szRet
    local szOutFile="$1"

    json_message "*****json_graph_get($szOutFile)"

    json_change_param szAuth $szAuth $tmpFile
    json_change_param szMapName "$szMapName" $tmpFile

    szRet=$(wget -4 --load-cookies=z.coo -O result.png 'http://$szAddress/zabbix/chart2.php?graphid=410&width=1778&period=102105&stime=20121129005934')
    if [ $szDebug == "s" ]; then
        json_message "    map.get: $szRet"
    fi

    szMapId=$(echo "$szRet" | jshon -Q -e "result" -e 0 -e "sysmapid")
    echo $szMapId
}
