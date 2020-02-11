#!/bin/bash

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

readonly FIRSTPWD=$(pwd)
readonly SCRIPTFOLDER=$(dirname $0)
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
CURRENTDB=''
CURRENTENVIRONMENT=''
LASTENVIRONMENT=''
OS=''


# PROJECT RELATED FUNCTIONS

function goToFirstPWD() {
    cd "$FIRSTPWD"
}
function goToScriptFolder() {
    goToFirstPWD
    cd "$SCRIPTFOLDER"
}

function goToPlatform() {
    goToFirstPWD
    cd "$SCRIPTFOLDER/$PLATFORM"
}

function goToCustom() {
    goToFirstPWD
    cd "$SCRIPTFOLDER/$CUSTOM"
}

function goToStorefront() {
    goToScriptFolder
    #goToFirstPWD
    cd "$STOREFRONT"
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
    CURRENTDB=$1_db
    docker start $CURRENTDB 
}

function stopDatabase() {
    if [ -z "$1" ]; then
        echo -e "\n\e[36mStopping current Docker database $CURRENTDB...\e[0m"
        docker stop $CURRENTDB
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
    mapfile -t COMPANYADDONS <<< $(ls -d *addon)
#    (IFS=,; echo "COMPANYADDONS = ${COMPANYADDONS[*]}")
}

function getInstalledCompanyAddons() {
    getCompanyAddons
    COMPANYADDONS_REGEX=$(IFS='|'; echo "${COMPANYADDONS[*]}")
    goToStorefront
    mapfile -t INSTALLEDCOMPANYADDONS <<< $(grep -Eo $COMPANYADDONS_REGEX extensioninfo.xml)
    echo "${INSTALLEDCOMPANYADDONS[*]}"
}

function getLastUsedEnvironment() {
    ENVIRONMENTS_REGEX=$(IFS='|'; echo "${!ENVIRONMENTS[*]}")
    goToStorefront
    mapfile -t LASTUSEDENVIRONMENT <<< $(grep -Eo "($ENVIRONMENTS_REGEX)addon" extensioninfo.xml)
    LASTENVIRONMENT="${LASTUSEDENVIRONMENT[*]//addon/}"
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
    kill $(lsof -t -i :8983) 2>/dev/null &&
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
    ant clean all
}

function startEnvironment() {
    echo -e "\n\e[36mStarting $1 environment...\e[0m"
    CURRENTENVIRONMENT=$1
    goToPlatform
    sh ./hybrisserver.sh debug
}

function switchToEnvironment() {
    echo -e "\n\e[46mSwitching to $1 environment...\e[0m"
    LASTENVIRONMENT="$1"
    prepareNodeEnvironment &&
    startDatabase $1 &&
    setAntEnvironment &&
    generateConfig &&
    setEnvironment $1 &&
    customize &&
    uninstallAddon "$@" &&
    installAddon $1 &&
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


# INTERNAL FUNCTIONS

function pressAnyKey() {
    read -n 1 -s -r -p "Press any key to continue"
}

function showOptions() {
    options=(
        "Switch to Pontmeyer"
        "Switch to Jongeneel"
        "Switch to RetInterieur"
        "Quick-start '$LASTENVIRONMENT' environment"
        "Set Node permissions"
        "TEST"
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
    PS3=$'\nPlease make a choise: '
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

            "Quick-start '$LASTENVIRONMENT' environment")
                clear
                echo "Executing: $opt"
                startDatabase $LASTENVIRONMENT &&
                setAntEnvironment &&
                startEnvironment $LASTENVIRONMENT ||
                echo -e "\n\e[41m>> Something goes wrong switching to the $LASTENVIRONMENT environment, please inspect logs above! <<\e[0m"
                stopDatabase
                stopSolrServer
            ;;

            "Set Node permissions")
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

            "TEST")
                clear
                echo -e "OS: \e[36m$OS\e[0m"
                echo -e "Script folder: \e[36m$SCRIPTFOLDER\e[0m"
                echo -e "Currently installed company addons: \e[36m$(getInstalledCompanyAddons)\e[0m"
                echo -e "Last used environment: \e[36m$LASTENVIRONMENT\e[0m"
                echo -e "CURRENTDB: \e[36m$CURRENTDB\e[0m"
                echo -e "CURRENTENVIRONMENT: \e[36m$CURRENTENVIRONMENT\e[0m"
            ;;

            "STOP")
                clear
                stopAllDockerContainers
                stopSolrServer
                break
            ;;

            *)
                echo -e "\n\e[31mSorry, that's not an option.\n\e[36mPick one of the numbers below:\e[0m"
            ;;

        esac
    done
else
    # Execute function direct via argument, e.g.: ./start.sh getInstalledCompanyAddons or ./start.sh switchToEnvironment retinterieur 
    "$@"
fi
