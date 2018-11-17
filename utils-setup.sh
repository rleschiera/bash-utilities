#! /bin/bash

#******************************************************************************
#
#     C H E C K
#
#******************************************************************************
function check_program()
{
    local   myCommand="$1"
    local   myFound=""

    # Controlla se e' installato il programma
    myFound=$(rpm -qa | grep "^$myCommand")
    if [ -z "$myFound" ]; then
        out_message "    $myCommand non installato: installarlo per proseguire."
        exit -1
    else
        out_message "    $myCommand: installato."
    fi
}

function check_sudo()
{
    local   myCommand="$1"
    local   myFound=""

    # Controlla se e' configurato il sudo per il comando
    myCanSudo=$(sudo -l | grep NOPASSWD | grep "$1" | wc -l)
    if [ $myCanSudo -gt 0 ]; then
        out_message "    sudo $myCommand: OK (su singolo comando)."
    else
        myCanSudo=$(sudo -l | grep NOPASSWD | grep ALL | wc -l)
        if [ $myCanSudo -gt 0 ]; then
            out_message "    sudo $myCommand: OK (ALL)."
        else
            out_message "    sudo $myCommand NOT OK: abilitarlo per proseguire."
            exit -1
        fi
    fi
}

#******************************************************************************
#
#     C R E A T E
#
#******************************************************************************
function create_dir()
{
    local szDir="$1"

    if [ ! -d "$szDir" ]; then
        mkdir -p "$szDir"
        out_message "    Directory $szDir creata."
    fi
}

function create_file()
{
    local szTo="$1"
    local szFrom="$2"

    if [ ! -f "$szTo" ]; then
        if [ -f "$szFrom" ]; then
            cp -f "$szFrom" "$szTo"
            out_message "    File $szTo creato."
        else
            out_message "    File sorgente $szFrom non trovato."
        fi
    fi
}

#******************************************************************************
#
#     C O N F I G U R E
#
#******************************************************************************
function config_service()
{
    local myService="$1"

    # Crea il file in /etc/init.d
    if [ -f $szTmplDir/init.d/$myService ]; then
        if [ -f /etc/init.d/$myService ]; then
            myDiff=$(diff /etc/init.d/$myService $szTmplDir/init.d/$myService)
            if [ ! -z myDiff ]; then
                sudo service $myService stop
                sudo cp -f $szTmplDir/init.d/$myService /etc/init.d/$myService
                sudo chmod 755 /etc/init.d/$myService
            fi
        else
            sudo cp -f $szTmplDir/init.d/$myService /etc/init.d/$myService
            sudo chmod 755 /etc/init.d/$myService
        fi
    else
        out_message "    Servizio $myService non trovato in configurazione." 
        exit -1
    fi

    # Aggiungi il servizio $myService
    myFound=$(chkconfig $myService)
    if [ -z myFound ]; then
        sudo chkconfig --add $myService 
    fi
    sudo chkconfig $myService on

    # Attiva il servizio
    sudo service $myService start
    out_message "    Servizio $myService creato e configurato."
}

function unconfig_service()
{
    local myService="$1"

    # Rimuovi il file da /etc/init.d
    if [ -f /etc/init.d/$myService ]; then
        sudo service $myService stop
        # sudo rm -f /etc/init.d/$myService
    else
        out_message "    Servizio $myService non trovato in configurazione." 
    fi

    # Rimuovi il servizio $myService
    myFound=$(chkconfig $myService)
    if [ ! -z $myFound ]; then
        sudo chkconfig --del $myService 
    fi
    out_message "    Servizio $myService rimosso."
}
