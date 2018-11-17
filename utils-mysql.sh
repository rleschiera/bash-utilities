#! /bin/bash

function sql2list()
{
    local myIn="$1"
    local myList=""
    local myTmpFile="/tmp/sql2list.txt"

    printf "%s\n" "$myIn" > $myTmpFile
    while read myLine; do
        if [ ! -z "$myLine" ]; then
            if [ -z "$myList" ]; then
                myList="$myLine"
            else
                myList="$myList,$myLine"
            fi
        fi
    done < $myTmpFile
    rm -f $myTmpFile

    echo -e "$myList"
}

#******************************************************************************
#
#     I T E M
#
#******************************************************************************
function mysql_update_item_interface()
{
    local szItemId="$1"
    local szInterfaceId="$2"
    local szSql="UPDATE items SET interfaceid = $szInterfaceId WHERE itemid = $szItemId"

    # Esegui lo statement SQL
    mysql zabbix -u zabbix -ppassword -se "$szSql"
}

function mysql_show_linkable_items()
{
    local szTable="$1"
    local szHostName="$2"
    local szSql="
select distinct 
    left(rpad('$szTable',16,' '),16) as livetable,
    if(h.host IS NOT NULL,left(rpad(h.host,30,' '),30),repeat('-',30)) as host,
    if(i.itemid IS NOT NULL,left(rpad(i.itemid,6,' '),6),'------') as newitem,
    if(wi.itemid IS NOT NULL,left(rpad(wi.itemid,6,' '),6),'------') as olditem,
    count(ldt.itemid) as count,
    i.key_ as key_
from 
    hosts h, items i, work_hosts wh, work_items wi, $szTable ldt 
where 
    h.host = '$szHostName' and
    h.host = wh.host and
    h.hostid = i.hostid and
    wh.hostid = wi.hostid and
    i.key_ = wi.key_ and
    wi.itemid = ldt.itemid
group by
    livetable, host, newitem, olditem, key_"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_linkable_items()
{
    local szTable="$1"
    local szHostName="$2"
    local szSql=""

    # Esegui lo statement SQL
    szSql="select distinct max(hostid) from work_hosts where host = '$szHostName'"
    # dbg_message "*************************************************"
    # dbg_message "1 SQL:$szSql"
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    # dbg_message "1 OUT:$szOut"
    if [ ! -z "$szOut" ]; then
        szOldHostId=$(echo "$szOut" | awk '{print $1}')

        szSql="select distinct hostid from hosts where host = '$szHostName'"
        # dbg_message "2 SQL:$szSql" 
        szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
        # dbg_message "2 OUT:$szOut" 
        if [ ! -z "$szOut" ]; then
            szNewHostId=$(echo "$szOut" | awk '{print $1}')

            szSql="select distinct itemid from $szTable where itemid in (select distinct itemid from work_items where hostid = $szOldHostId)"
            # dbg_message "3 SQL:$szSql" 
            szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
            # dbg_message "3 OUT:$szOut" 
            if [ ! -z "$szOut" ]; then
                szItemList=$(sql2list "$szOut")
                if [ ! -z "$szItemList" ]; then

                    szSql="select distinct i.itemid, wi.itemid, wi.key_ from items i, work_items wi where i.hostid = $szNewHostId and i.key_ = wi.key_ and wi.itemid in ($szItemList)"
                    # dbg_message "4 SQL:$szSql" 
                    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
                    # dbg_message "4 OUT:$szOut" 
                fi
            fi
        fi
    fi

    echo "$szOut"
}

function mysql_update_linkable_item()
{
    local szTable="$1"
    local szOldId="$2"
    local szNewId="$3"
    local szSql="update $szTable set itemid = $szNewId where itemid = $szOldId"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_delete_unlinked_data()
{
    local myTable="$1"
    local myHost="$2"
    local myOut=""
    local myTmpFile="/tmp/mysql_delete_unlinked_data.txt"
    local mySql1="select wi.itemid from work_hosts wh, work_items wi where wh.hostid = $myHost and wh.hostid = wi.hostid"

    # Calcola la lista di itemid da cancellare nella tabella work
    mysql zabbix -u zabbix -ppassword -se "$mySql1" > $myTmpFile
    while read myLine; do
        mySql="delete from $myTable where itemid = $myLine"
        myOut=$(mysql zabbix -u zabbix -ppassword -se "$mySql")
    done < $myTmpFile

    rm -f $myTmpFile
    echo "1"
}

#******************************************************************************
#
#     H O S T
#
#******************************************************************************
function mysql_host_update()
{
    local szHostId="$1"
    local szIP="$2" 
    local szOldIPSql="select distinct ip from interface where hostid = $szHostId and main <> 0"
    local szIPSql=""

    # Aggiorna l'indirizzo IP
    szOldIP=$(mysql zabbix -u zabbix -ppassword -se "$szOldIPSql")
    if [ ! -z "$szOldIP" ]; then
        szIPSql="update interface set ip = '$szIP' where hostid = $szHostId and ip = '$szOldIP'"
        mysql zabbix -u zabbix -ppassword -se "$szIPSql"
    fi
}

function mysql_host_delete()
{
    local szHostId="$1"
    local szHostSql="insert into work_hosts (hostid, host) select hostid, host from hosts where hostid = $szHostId"
    local szItemSql="insert into work_items (hostid, itemid, key_) select hostid, itemid, key_ from items where hostid = $szHostId"

    # Esegui lo statement SQL
    mysql zabbix -u zabbix -ppassword -se "$szHostSql"
    mysql zabbix -u zabbix -ppassword -se "$szItemSql"
}

function mysql_host_count_items()
{
    local szHostId="$1"
    local szSearchKey="$2"
    local szSql=""

    # Prepara lo statement SQL
    if [ -z "$szSearchKey" ]; then
        szSql="select count(*) from items where hostid = $szHostId"
    else
        szSql="select count(*) from items where hostid = $szHostId and key_ like '%$szSearchKey%'"
    fi

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_host_delete_items()
{
    local szHostId="$1"
    local szSearchKey="$2"
    local szSql=""

    # Prepara lo statement SQL
    if [ -z "$szSearchKey" ]; then
        szSql="delete from items where hostid = $szHostId"
    else
        szSql="delete from items where hostid = $szHostId and key_ like '%$szSearchKey%'"
    fi

    # Esegui lo statement SQL
    mysql zabbix -u zabbix -ppassword -se "$szSql"
}

function mysql_host_item_getid()
{
    local szHostId="$1"
    local szItemName="$2"
    local szSql="select itemid from items where hostid = $szHostId and name = '$szItemName'"

    # Esegui lo statement SQL
    szItemId=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szItemId"
}

function mysql_host_has_template()
{
    local szHostId="$1"
    local szTemplateId="$2"
    local szSql="select templateid from hosts_templates where hostid = $szHostId and templateid = $szTemplateId"
    local szResult="false"

    # Esegui lo statement SQL
    # dbg_message "$szSql" 
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    if [ ! -z "$szOut" ]; then
        szResult="true"
    fi
    echo $szResult
}

function mysql_select_unlinked_hosts()
{
    local szHistoryTable="$1"
    local szSql="
select
    if(wh.hostid IS NOT NULL,wh.hostid,'-----') as hostid,
    if(wh.host IS NOT NULL,left(rpad(wh.host,30,' '),30),repeat('-',30)) as host,
    left(rpad('$szHistoryTable',16,' '),16) as livetable,
    count(ht.itemid) as count
from
    work_hosts wh, work_items wi, $szHistoryTable ht
where
    wh.host not in (select distinct h.host from hosts h) and wh.hostid = wi.hostid and
    wi.itemid = ht.itemid
group by
    hostid, host, livetable"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_show_linkable_hosts()
{
    local szTable="$1"
    local szSql="
select distinct
    left(rpad('$szTable',16,' '),16) as livetable,
    left(rpad(h.host,30,' '),30) as host,
    left(rpad(h.hostid,8,' '),8) as newid,
    left(rpad(wh.hostid,8,' '),8) as oldid,
    count(ldt.itemid) as count
from
    hosts h, work_hosts wh, work_items wi, $szTable as ldt
where
    h.host = wh.host and
    wh.hostid = wi.hostid and
    wi.itemid = ldt.itemid
group by
    livetable, host, newid, oldid"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_linkable_hosts()
{
    local szTable="$1"
    local szSql="
select distinct
    h.host as host,
    h.hostid as newid,
    wh.hostid as oldid
from
    hosts h, work_hosts wh, work_items wi, $szTable as ldt
where
    h.host = wh.host and
    wh.hostid = wi.hostid and
    wi.itemid = ldt.itemid"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_hosts_to_discovery()
{
    local szSql="
select distinct
    concat('server','|',h.name,'|',itf.ip)
from
    hosts h, hosts_templates ht, hosts t, interface itf
where
    t.name like 'Server%' and t.hostid = ht.templateid and ht.hostid = h.hostid
    and h.hostid = itf.hostid and itf.main > 0"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_count_host_interfaces()
{
    local szHostId="$1"
    local szInterfaceType="$2"
    local szSql="
select
    count(*)
from
    interface
where
    hostid = $szHostId and type = $szInterfaceType"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_get_host_interface_number()
{
    local szHostId="$1"
    local szInterfaceType="$2"
    local szPort="$3"
    local myTmpFile="/tmp/mysql_get_host_interface_number.txt"
    local iCount=1
    local myOutCount=""
    local szSql="
select
    port
from
    interface
where
    hostid = $szHostId and type = $szInterfaceType
order by
    port"

    # Esegui lo statement SQL
    mysql zabbix -u zabbix -ppassword -se "$szSql" > $myTmpFile
    while read myLine; do
        myPort=$(echo "$myLine" | awk '{print $1}')
        if [ $szPort == $myPort ]; then
            # out_message "L'interfaccia $szInterfaceType ha numero $iCount"
            myOutCount="$iCount"
        fi
        let iCount++
    done < $myTmpFile

    if [ -z "$myOutCount" ]; then
        out_error "Interfaccia per la porta $szPort non trovata."
    fi
    echo "$myOutCount"
}

#******************************************************************************
#
#     H O S T G R O U P
#
#******************************************************************************
function mysql_hostgroup_has_host()
{
    local szHostGroupId="$1"
    local szHostId="$2"
    local szSql="select hostid from hosts_groups where groupid = $szHostGroupId and hostid = $szHostId"

    # Esegui lo statement SQL
    # dbg_message "$szSql"
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_hostgroup_has_template()
{
    local szHostGroupId="$1"
    local szTemplateId="$2"
    local szSql="select hostid from hosts_groups where groupid = $szHostGroupId and hostid = $szHostId"

    # Esegui lo statement SQL
    # dbg_message "$szSql"
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_hostgroup_delete()
{
    local szGroupId="$1"
}

#******************************************************************************
#
#     T E M P L A T E
#
#******************************************************************************
function mysql_template_delete()
{
    local szTemplateId="$1"
}

function mysql_select_related_template()
{
    local szHostName="$1"
    local szSourceTemplateType="$2"
    local szSourceTemplate="$3"
    local szRelatedTemplate="$4"
    local szInterfaceId
    local szSql2=""
    local szSql1="
select distinct
    itm_h.interfaceid
from
    hosts tpl_j, items itm_j, items itm_h, hosts hst_h
where
    tpl_j.name = '$szSourceTemplateType $szSourceTemplate' and tpl_j.hostid = itm_j.hostid and
    itm_j.key_ = itm_h.key_ and itm_h.hostid = hst_h.hostid and hst_h.name = '$szHostName' and 
    itm_h.interfaceid is not null"

    # Esegui lo statement SQL
    # dbg_message "SQL1:$szSql1"
    szInterfaceId=$(mysql zabbix -u zabbix -ppassword -se "$szSql1")
    # dbg_message "InterfaceId: $szInterfaceId"

    if [ ! -z "$szInterfaceId" ]; then
        szSql2="
select distinct
    t.name
from
    hosts t, items itm
where
    t.hostid = itm.hostid and
    t.name like '$szRelatedTemplate $szSourceTemplate%' and
    itm.key_ in (select distinct key_ from items where interfaceid = $szInterfaceId)"

        # dbg_message "SQL2: $szSql2"
        szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql2")
        # dbg_message "Related template: $szOut"
    else
        out_message "Related template '$szSourceTemplateType $szSourceTemplate' per '$szHostName' non trovato."
        szOut=""
    fi
    echo "$szOut"
}

#******************************************************************************
#
#     M A P
#
#******************************************************************************
function mysql_select_map_objects_to_create()
{
    local szGroupName="$1"
    local szTemplateName="$2"
    local szSql="
select
    H.hostid hostid, H.host host, T.hostid templateid, T.host template
from
    hosts H, hosts_templates HT, hosts T, hosts_groups HG, groups G
where
    H.status in (0,1) and
    H.hostid not in (select distinct HT.templateid from hosts_templates HT) and
    H.hostid = HG.hostid and
    HG.groupid = G.groupid and
    G.name like '$szGroupName' and
    H.hostid = HT.hostid and
    HT.templateid = T.hostid and
    (T.host like '$szTemplateName' or '$szTemplateName' = '')"
    # dbg_message "1:$szGroupName,2:$szTemplateName,SQL:$szSql"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_map_objects_to_update()
{
    local szMapName="$1"
    local szGroupName="$2"
    local szTemplateName="$3"
    local szSql="
select distinct
    H.hostid hostid, H.host host, T.hostid templateid, T.host template
from
    hosts H, hosts_templates HT, hosts T, hosts_groups HG, groups G
where
    H.status in (0,1) and
    H.hostid not in (select distinct HT.templateid from hosts_templates HT) and
    H.hostid = HG.hostid and
    HG.groupid = G.groupid and
    G.name like '$szGroupName' and
    H.hostid = HT.hostid and
    HT.templateid = T.hostid and
    (T.host like '$szTemplateName' or '$szTemplateName' = '') and
    H.hostid not in (select elementid from sysmaps M, sysmaps_elements ME where M.name = '$szMapName' and M.sysmapid = ME.sysmapid)"
    # dbg_message "1:$szGroupName,2:$szTemplateName,SQL:$szSql"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_map_objects()
{
    local szMapName="$1"
    local szSql="
select
    ME.elementid as hostid, ME.iconid_off as iconid, ME.x as x, ME.y as y
from 
    sysmaps M, sysmaps_elements ME 
where 
    M.name = '$szMapName' and M.sysmapid = ME.sysmapid"

    # Esegui lo statement SQL
    # dbg_message "SQL:$szSql" 
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

#******************************************************************************
#
#     S C R E E N
#
#******************************************************************************
function mysql_select_hosts_with_screens()
{
    local szScreenType="$1"
    local szApplicationName="$2"
    local szSql="
select distinct
    concat(lower('$szScreenType'),'|',h.name)
from
    hosts h, hosts_templates ht, hosts t, applications a
where
    t.name like '$szScreenType%' and t.hostid = ht.templateid and ht.hostid = h.hostid and h.hostid = a.hostid and a.name like '$szApplicationName%'"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_jvm_screens()
{
    local szHostName="$1"
    local szSql="
select distinct
    substring(t.name,char_length('JVM')+2,99)
from
    hosts h, hosts_templates ht, hosts t, applications a
where
    h.name = '$szHostName' and t.hostid = ht.templateid and
    ht.hostid = h.hostid and h.hostid = a.hostid and
    lower(t.name) like 'jvm%'"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_select_tomcat_screens()
{
    local szHostName="$1"
    local szType="$2"
    local szSql="
select distinct
    substring(t.name,char_length('Tomcat')+2,99)
from
    hosts h, hosts_templates ht, hosts t, applications a
where
    h.name = '$szHostName' and t.hostid = ht.templateid and
    ht.hostid = h.hostid and t.hostid = a.hostid and
    lower(t.name) like 'tomcat%' and lower(a.name) like '$szType-%'"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

#******************************************************************************
#
#     H T T P     T E S T
#
#******************************************************************************
function mysql_httptest_exists()
{
    local szHostId=$(clear_quotes "$1")
    local szName="$2"
    local szSql="select name from httptest where hostid = '$szHostId' and name = '$szName'"

    # Esegui lo statement SQL
    # dbg_message "$szSql"
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

function mysql_httptest_getid()
{
    local szHostId=$(clear_quotes "$1")
    local szName="$2"
    local szSql="select httptestid from httptest where hostid = '$szHostId' and name = '$szName'"

    # Esegui lo statement SQL
    # dbg_message "$szSql"
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

#******************************************************************************
#
#     M E D I A
#
#******************************************************************************
function mysql_select_media_id()
{
    local szMediaName="$1"
    local szSql="
select distinct
    mediatypeid
from
    media_type
where
    description = '$szMediaName'"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

#******************************************************************************
#
#     T R E N D
#
#******************************************************************************
function mysql_get_last_trend_clock()
{
    local szSql="
select
    max(clock)
from
    (select max(clock) as clock from trends union select max(clock) as clock from trends_uint) t"

    # Esegui lo statement SQL
    szOut=$(mysql zabbix -u zabbix -ppassword -se "$szSql")
    echo "$szOut"
}

#******************************************************************************
#
#     M A I N T EN A N C E S
#
#******************************************************************************
function mysql_delete_maintenance()
{
    local szHostName="$1"
    local szName="$2"
    local szId=""
    local szSql="
select
    maintenanceid
from
    maintenances
where
    name = '$szHostName: $szName'"

    # Esegui lo statement SQL
    szId=$(mysql zabbix -u zabbix -ppassword -se "$szSql")

    if [ ! -z "$szId" ]; then
        szSql="delete from maintenances_groups where maintenanceid = $szId"
        mysql zabbix -u zabbix -ppassword -se "$szSql"
        szSql="delete from maintenances_hosts where maintenanceid = $szId"
        mysql zabbix -u zabbix -ppassword -se "$szSql"
        szSql="delete from maintenances_windows where maintenanceid = $szId"
        mysql zabbix -u zabbix -ppassword -se "$szSql"
        szSql="delete from maintenances where maintenanceid = $szId"
        mysql zabbix -u zabbix -ppassword -se "$szSql"
    fi
}
