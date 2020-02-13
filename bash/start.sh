#!/bin/bash
# >>> PUT THIS SCRIPT OUTSIDE THE ROOT OF THE GIT REPO (1 level higher) <<<


# DESCRIPTION:

# The purpose of this script is to simplify the working environment for a front-end developer in a multi-project SAP Hybris environment.


# DOCUMENTATION:

# Switch environment from pontmeyer to jongeneel:
# ===============================================
# ant generate_config
# ant set_environment -DuseConfig=jng-local
# ant customize
# chmod +x resources/ant/lib/linux/node
# ant addoninstall -Daddonnames='smarteditaddon,b2bpunchoutaddon,jongeneeladdon,commerceorgaddon,commerceorgsamplesaddon,secureportaladdon,b2bacceleratoraddon,adaptivesearchsamplesaddon,assistedservicestorefront,tabsaddon' -DaddonStorefront.yacceleratorstorefront='pontmeyerstorefront'
# (ant addonuninstall -Daddonnames='pontmeyeraddon' -DaddonStorefront.yacceleratorstorefront='pontmeyerstorefront')
# (kill $(lsof -t -i :8983)) 
# ant clean all && sh ./hybrisserver.sh debug

# Startup:
# ========
# sudo docker exec -it jongeneel_db "bash"
# cd HYBRISCOMM6600P_0-70003031/hybris/bin/platform/
# ant set_environment -DuseConfig=jng-local
# ant clean all && sh ./hybrisserver.sh debug

# All-in-one (hybris) startup:
# ============================
# ant generate_config && ant set_environment -DuseConfig=jng-local && ant customize && ant clean all && sh ./hybrisserver.sh debug

# mysql dump via docker:
# ======================
# docker exec pontmeyer_db /usr/bin/mysqldump -u root --password=root pontmeyer | gzip > `date +%Y%m%d`-pontmeyer.sql.gz` 

# mysql dump import via docker :
# ==============================
# zcat 20190527-pontmeyer.sql.gz | docker exec -i pontmeyer_db /usr/bin/mysql -u root --password=root

# Detect which project / company has been loaded:
# ===============================================
# cd "$(dirname $0)/$STOREFRONT"
# grep -Eo '(pontmeyer|jongeneel)addon' extensioninfo.xml

readonly FIRST_PWD=$(pwd)
readonly SCRIPT_FOLDER=$(dirname $0)
readonly BIN='HYBRISCOMM6600P_0-70003031/hybris/bin'
readonly PLATFORM="$BIN/platform"
readonly CUSTOM="$BIN/custom"
readonly STOREFRONT="$CUSTOM/pontmeyerstorefront"
declare -A ENVIRONMENTS=(
    [pontmeyer]=ptm
    [jongeneel]=jng
    [retinterieur]=ret
)
COMPANYADDONS=''
CHOSEN_DB=''
CHOSEN_ENVIRONMENT=''
LAST_ENVIRONMENT=''
OS=''


# PROJECT RELATED FUNCTIONS

function goToFIRST_PWD() {
    cd "$FIRST_PWD" || return
}
function goToSCRIPT_FOLDER() {
    goToFIRST_PWD
    cd "$SCRIPT_FOLDER" || return
}

function goToPlatform() {
    goToFIRST_PWD
    cd "$SCRIPT_FOLDER/$PLATFORM" || return
}

function goToCustom() {
    goToFIRST_PWD
    cd "$SCRIPT_FOLDER/$CUSTOM" || return
}

function goToStorefront() {
    goToSCRIPT_FOLDER
    #goToFIRST_PWD
    cd "$STOREFRONT" || return
}

function getOS() {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        OS='linux'
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS='darwin'
    else
        OS='unsupported'
    fi
}

function startDatabase() {
    echo -e "\n\e[36mStarting Docker database $1_db...\e[0m"
    CHOSEN_DB=$1_db
    docker start $CHOSEN_DB 
}

function stopDatabase() {
    if [ -z "$1" ]; then
        echo -e "\n\e[36mStopping Docker database $CHOSEN_DB...\e[0m"
        docker stop $CHOSEN_DB
    else
	      echo -e "\n\e[36mStopping Docker database $1_db...\e[0m"
	      docker stop $1_db
    fi
}

function setAntEnvironment() {
    echo -e "\n\e[36mSetting Ant environment...\e[0m"
    goToPlatform
    . ./setantenv.sh
}

function generateConfig() {
    echo -e "\n\e[36mAnt generate_config...\e[0m"
    goToPlatform &&
    ant generate_config
}

function setEnvironment() {
    echo -e "\n\e[36mAnt set_environment to ${ENVIRONMENTS[$1]}-local...\e[0m"
    goToPlatform &&
    ant set_environment -DuseConfig=${ENVIRONMENTS[$1]}-local
}

function customize() {
    echo -e "\n\e[36mAnt customize...\e[0m"
    goToPlatform &&
    ant customize
}

function getCompanyAddons() {
    goToCustom
    mapfile -t COMPANYADDONS <<< "$(ls -d *addon)"
#    (IFS=,; echo "COMPANYADDONS = ${COMPANYADDONS[*]}")
}

function getInstalledCompanyAddons() {
    getCompanyAddons
    COMPANYADDONS_REGEX=$(IFS='|'; echo "${COMPANYADDONS[*]}")
    goToStorefront
    mapfile -t INSTALLEDCOMPANYADDONS <<< "$(grep -Eo $COMPANYADDONS_REGEX extensioninfo.xml)"
    echo "${INSTALLEDCOMPANYADDONS[*]}"
}

function getLastUsedEnvironment() {
    ENVIRONMENTS_REGEX=$(IFS='|'; echo "${!ENVIRONMENTS[*]}")
    goToStorefront
    mapfile -t LASTUSEDENVIRONMENT <<< "$(grep -Eo "($ENVIRONMENTS_REGEX)addon" extensioninfo.xml)"
    LAST_ENVIRONMENT="${LASTUSEDENVIRONMENT[*]//addon/}"
}

function installAddon() {
    ant addoninstall -Daddonnames="smarteditaddon,b2bpunchoutaddon,$1addon,commerceorgaddon,commerceorgsamplesaddon,secureportaladdon,b2bacceleratoraddon,adaptivesearchsamplesaddon,assistedservicestorefront,tabsaddon" -DaddonStorefront.yacceleratorstorefront="pontmeyerstorefront" 
}

function uninstallAddon() {
    if [ -z "$1" ]; then
	      COMPANYADDONS_CSV=$(IFS=,; getInstalledCompanyAddons)
	      echo -e "\n\e[36mUninstalling all active company addons ($COMPANYADDONS_CSV)...\e[0m"
       	ant addonuninstall -Daddonnames="$COMPANYADDONS_CSV" -DaddonStorefront.yacceleratorstorefront="pontmeyerstorefront"
    else
        echo -e "\n\e[36mUninstalling addon $1addon...\e[0m"
        ant addonuninstall -Daddonnames="$1addon" -DaddonStorefront.yacceleratorstorefront="pontmeyerstorefront"
    fi
}

function stopSolrServer() {
    echo -e "\n\e[36mStopping Solr server...\e[0m"
    kill "$(lsof -t -i :8983)" 2>/dev/null &&
    echo -e "Solr server is no more.\n" ||
    echo -e "Solr server was already dead.\n"
}

function stopAllDockerContainers() {
    DOCKER_CONTAINERS=$(docker ps --format "{{.Names}}")

    if [[ -n "$DOCKER_CONTAINERS" ]]; then
	      echo -e "\n\e[36mStopping Docker containers:\e[0m"
        docker stop $DOCKER_CONTAINERS 
    else
        echo -e "\n\e[36mNo Docker containers were running.\e[0m"
    fi
} 

function buildEnvironment() {
    echo -e "\n\e[36mAnt Clean All...\e[0m"
    goToPlatform
    ant clean all
}

function startEnvironment() {
    echo -e "\n\e[36mStarting $1 Hybris environment...\e[0m"
    CHOSEN_ENVIRONMENT=$1
    goToPlatform
    sh ./hybrisserver.sh debug
}

function switchToEnvironment() {
    echo -e "\n\e[46mSwitching to $1 environment...\e[0m"
    LAST_ENVIRONMENT="$1"
    prepareNodeEnvironment &&
    startDatabase $1 &&
    setAntEnvironment &&
    generateConfig &&
    setEnvironment $1 &&
    customize &&
    uninstallAddon "$@" &&
    installAddon $1 &&
    echo -e "\n\e[36mPress any key if Hybris needs to startup with wro4j enabled, by default wro4j will be disabled after a few seconds...\e[0m" &&
    waitConfirm 'wro4j disable' 'wro4j enable' &&
    buildEnvironment &&
    startEnvironment $1 || 
    echo -e "\n\e[41m>> Something goes wrong switching to the $1 environment, please inspect logs above! <<\e[0m"
    stopDatabase
    stopSolrServer
}

function prepareNodeEnvironment() {
    if [ -d ~/.nvm ]; then
        . ~/.nvm/nvm.sh
        nvm i 8
    else
        echo -e "\e[33mIf you have multiple projects using different Node versions, NVM (Node Version Manager) is a recommended tool.\n\nYou can find it here: https://github.com/nvm-sh/nvm if you want this script to automatically switch to the right Node version for this project.\e[0m"
    fi
}

function wro4j() {
    local projectPropertiesFile="${STOREFRONT}/project.properties"
    local wroPropertiesFile="${STOREFRONT}/web/webroot/WEB-INF/wro.properties"
    local wro4jEnabled='storefront.wro4j.enabled'
    local wro4jEnabledComment='#########\n# Wro4j #\n#########'
    local wroDebug='debug'

    goToSCRIPT_FOLDER
    if [ -f "$projectPropertiesFile" ]; then
        case $1 in

            "status")
                wro4j inspectProjectProperties
                wro4j inspectWroProperties
            ;;

            "inspectProjectProperties")
                while IFS='=' read -r key value
                do
                    key=$(echo $key | tr '.-' '_')
                    [[ ! -z "$key" ]] && eval ${key}=\${value}
                done < "$projectPropertiesFile"

                # If storefront.wro4j.enabled property exists, return it:
                [ ${storefront_wro4j_enabled} ] && echo "${wro4jEnabled}=${storefront_wro4j_enabled}"
            ;;

            "inspectWroProperties")
                while IFS='=' read -r key value
                do
                    key=$(echo $key | tr '.-' '_')
                    [[ ! -z "$key" ]] && eval ${key}=\${value}
                done < "$wroPropertiesFile"

                # If debug property exists, return it:
                [ ${debug} ] && echo "${wroDebug}=${debug}"
            ;;

            "enable")
                echo -e "\n\e[36mEnabling wro4j...\e[0m"

                # If storefront.wro4j.enabled property is available: modify it, otherwise append it to the project.properties file
                if (wro4j inspectProjectProperties > /dev/null); then
                    sed -i'' -e "s/${wro4jEnabled}=false/${wro4jEnabled}=true/" ${projectPropertiesFile}
                    echo "The property ${wro4jEnabled} has been modified in ${projectPropertiesFile}"
                else
                    echo -e "\n${wro4jEnabledComment}\n${wro4jEnabled}=true" >> ${projectPropertiesFile}
                    echo "The property ${wro4jEnabled} has been appended to ${projectPropertiesFile}"
                fi

                # If debug property is available: modify it in the wro.properties file
                if (wro4j inspectWroProperties > /dev/null); then
                    sed -i'' -e "s/${wroDebug}=true/${wroDebug}=false/" ${wroPropertiesFile}
                    echo "The property ${wroDebug} has been modified in ${wroPropertiesFile}"
                fi
            ;;

            "disable")
                echo -e "\n\e[36mDisabling wro4j...\e[0m"

                # If storefront.wro4j.enabled property is available: modify it, otherwise append it to the project.properties file
                if (wro4j inspectProjectProperties > /dev/null); then
                    sed -i'' -e "s/${wro4jEnabled}=true/${wro4jEnabled}=false/" ${projectPropertiesFile}
                    echo "The property ${wro4jEnabled} has been modified in ${projectPropertiesFile}"
                else
                    echo -e "\n${wro4jEnabledComment}\n${wro4jEnabled}=false" >> ${projectPropertiesFile}
                    echo "The property ${wro4jEnabled} has been appended to ${projectPropertiesFile}"
                fi

                # If debug property is available: modify it in the wro.properties file
                if (wro4j inspectWroProperties > /dev/null); then
                    sed -i'' -e "s/${wroDebug}=false/${wroDebug}=true/" ${wroPropertiesFile}
                    echo "The property ${wroDebug} has been modified in ${wroPropertiesFile}"
                fi
            ;;

            *)
                echo -e "\e[33mWARNING: No or unrecognized argument specified\e[0m -> usage: wro4j status | enable | disable"
                echo -e "\nwro4j status: "
                wro4j status
            ;;

        esac
    else
        echo -e "\e[33mWARNING: file not found: $projectPropertiesFile\e[0m"
        [ $1 ] && echo -e "As a result of this missing file, \e[36mwro4j $1\e[0m cannot be executed."
    fi
}


# INTERNAL FUNCTIONS

function pressAnyKey() {
    read -n 1 -s -r -p "Press any key to continue"
}

# Usage: autoConfirm xxx yyy
# -> this will wait for a few seconds to give the user a chance to execute yyy instead of xxx
# -> after a timeout (without any key pressed) it will automatically execute xxx by default
function waitConfirm() {
    if [ "$1" ] && [ "$2" ]; then
        read -t 10 -s -N 1 key
        if [[ $key ]]; then
            echo -e "\n\e[36mStarting ${2}...\e[0m"
            eval "${2}"
            return
        else
            echo -e "\n\e[36mStarting ${1}...\e[0m"
            eval "${1}"
            return
        fi
    else
        echo -e "\e[33mWARNING: Not enough arguments specified\e[0m -> usage: waitConfirm xxx yyy"
    fi
}

function showOptions() {
    options=(
        "Switch to Pontmeyer"
        "Switch to Jongeneel"
        "Switch to RetInterieur"
        "Quick-restart '$LAST_ENVIRONMENT' environment (no build)"
        "Set NodeJS exec permission"
        "Enable wro4j"
        "Disable wro4j"
        "INFO"
        "STOP"
    )
    select opt in "${options[@]}"; do
        echo $opt
        break
    done
}


# MENU

if [ "_$1" = "_" ]; then
    
    BANNER=$'\n\e[46mTabs Holland environment options\e[0m\e[36m\n================================\e[0m\n'
    PS3=$'\nPlease make a choice: '
    while true; do
        echo -e "$BANNER"
        getOS
        getLastUsedEnvironment
        opt=$(showOptions)
        case $opt in

            "Switch to Pontmeyer")
                clear
                echo "Executing: $opt"
                switchToEnvironment pontmeyer
            ;;

            "Switch to Jongeneel")
                clear
                echo "Executing: $opt"
                switchToEnvironment jongeneel
            ;;

            "Switch to RetInterieur")
                clear
                echo "Executing: $opt"
                switchToEnvironment retinterieur 
            ;;

            "Quick-restart '$LAST_ENVIRONMENT' environment (no build)")
                clear
                echo "Executing: $opt"
                startDatabase $LAST_ENVIRONMENT &&
                setAntEnvironment &&
                startEnvironment $LAST_ENVIRONMENT ||
                echo -e "\n\e[41m>> Something goes wrong switching to the $LAST_ENVIRONMENT environment, please inspect logs above! <<\e[0m"
                stopDatabase
                stopSolrServer
            ;;

            "Set NodeJS exec permission")
                clear
                if [ "$OS" != "unsupported"  ]; then
                    NODE="resources/ant/lib/${OS}/node"
                    echo -e "\e[36mSetting execute permission for $NODE:\e[0m"
                    goToPlatform
                    chmod +x $NODE
                    ls -al $NODE
                    else
                    echo "Sorry, only Linux and Mac are supported in this setup."
                fi
            ;;

            "Enable wro4j")
                clear
                wro4j enable
                wro4j status
            ;;

            "Disable wro4j")
                clear
                wro4j disable
                wro4j status
            ;;

            "TEST")
                clear
                echo 'Press any key to execute "uname -a", otherwise "ls -al" will be executed after 5 seconds.'
                waitConfirm 'uname -a' 'ls -al'
            ;;

            "INFO")
                clear
                echo -e "OS: \e[36m$OS\e[0m"
                echo -e "Script folder: \e[36m$SCRIPT_FOLDER\e[0m"
                echo -e "Currently installed company addons: \e[36m$(getInstalledCompanyAddons)\e[0m"
                echo -e "Last used environment: \e[36m$LAST_ENVIRONMENT\e[0m"
                [ ${CHOSEN_DB} ] && echo -e "CHOSEN_DB: \e[36m$CHOSEN_DB\e[0m"
                [ ${CHOSEN_ENVIRONMENT} ] && echo -e "CHOSEN_ENVIRONMENT: \e[36m$CHOSEN_ENVIRONMENT\e[0m"
                echo -e "wro4j / debug settings: \e[36m\n$(wro4j 'status')\e[0m"
            ;;

            "STOP")
                clear
                stopSolrServer
                stopAllDockerContainers
                break
            ;;

            *)
                echo -e "\n\e[31mSorry, that's not an option.\n\e[36mPick one of the numbers below:\e[0m"
            ;;

        esac
    done
else
    # Execute function direct via argument, e.g.:
    # ./start.sh getInstalledCompanyAddons
    # ./start.sh switchToEnvironment retinterieur
    # ./start.sh wro4j status
    "$@"
fi
