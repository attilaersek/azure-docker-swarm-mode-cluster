#!/bin/bash

usage() { 
    echo "Usage:"
    echo " $0 --subscriptionId <subscriptionId> --resourceGroupName <resourceGroupName> --deploymentName <deploymentName> --parametersFile <parametersFile> [ --resourceGroupLocation <resourceGroupLocation> ]" 
    1>&2; 
    exit 1; 
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

#templateFile Path - template file to be used
templateFilePath="$DIR/template.json"

#parameter file path
parametersFile="$DIR/parameters.json"

i=$(($# + 1)) # index of the first non-existing argument
declare -A longoptspec
longoptspec=( [subscriptionId]=1 [resourceGroupName]=1 [deploymentName]=1 [resourceGroupLocation]=1 [parametersFile]=1 )
optspec=":s:g:n:p:l:-:"
while getopts "$optspec" opt; do
    while true; do
        case "${opt}" in
            -) #OPTARG is name-of-long-option or name-of-long-option=value
                if [[ ${OPTARG} =~ .*=.* ]] # with this --key=value format only one argument is possible
                then
                    opt=${OPTARG/=*/}
                    ((${#opt} <= 1)) && {
                        echo "Syntax error: Invalid long option '$opt'" >&2
                        exit 2
                    }
                    if (($((longoptspec[$opt])) != 1))
                    then
                        echo "Syntax error: Option '$opt' does not support this syntax." >&2
                        exit 2
                    fi
                    OPTARG=${OPTARG#*=}
                else #with this --key value1 value2 format multiple arguments are possible
                    opt="$OPTARG"
                    ((${#opt} <= 1)) && {
                        echo "Syntax error: Invalid long option '$opt'" >&2
                        exit 2
                    }
                    OPTARG=(${@:OPTIND:$((longoptspec[$opt]))})
                    ((OPTIND+=longoptspec[$opt]))
                    ((OPTIND > i)) && {
                        echo "Syntax error: Not all required arguments for option '$opt' are given." >&2
                        exit 3
                    }
                fi

                continue #now that opt/OPTARG are set we can process them as
                # if getopts would've given us long options
                ;;
            s|subscriptionId)
                subscriptionId=$OPTARG
                ;;
            g|resourceGroupName)
                resourceGroupName=$OPTARG
                ;;
            n|deploymentName)
                deploymentName=$OPTARG
                ;;
            p|parametersFile)
                parametersFile=$OPTARG
                ;;
            l|resourceGroupLocation)
                resourceGroupLocation=$OPTARG
                ;;
            ?)
                echo "Syntax error: Unknown short option '$OPTARG'" >&2
                exit 2
                ;;
            *)
                echo "Syntax error: Unknown long option '$opt'" >&2
                exit 2
                ;;
        esac
        break; 
    done
done

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$deploymentName" ] || [ -z "$parametersFile" ]; then
	echo "Either one of subscriptionId, resourceGroupName, deploymentName or parametersFile is empty"
	usage
fi

#login to azure using your credentials
#azure login

#set the default subscription id
azure account set $subscriptionId

#switch the mode to azure resource manager
azure config mode arm

#Check for existing resource group
if [ -z "$resourceGroupLocation" ] ; 
then
	echo "Using existing resource group..."
else 
	echo "Creating a new resource group..." 
	azure group create --name $resourceGroupName --location $resourceGroupLocation
fi

#Start deployment
echo "Starting deployment..."
azure group deployment create --name $deploymentName --resource-group $resourceGroupName --template-file $templateFilePath --parameters-file $parametersFile