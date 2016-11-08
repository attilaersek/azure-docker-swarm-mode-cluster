#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

i=$(($# + 1)) # index of the first non-existing argument
declare -A longoptspec
longoptspec=( [subscriptionId]=1 [resourceGroupName]=1 [resourceGroupLocation]=1 [adminUserName]=1 [sshPublicKeyFile]=1 [storageNamePrefix]=1 [agentIndex]=1 [customDataFile]=1 )
optspec=":s:g:l:u:k:t:i:c:-:"
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
            l|resourceGroupLocation)
                resourceGroupLocation=$OPTARG
                ;;
            k|sshPublicKeyFile)
                sshPublicKeyFile=$OPTARG
                ;;
            u|adminUserName)
                adminUserName=$OPTARG
                ;;
            t|storageNamePrefix)
                storageNamePrefix=$OPTARG
                ;;
            i|agentIndex)
                agentIndex=$OPTARG
                ;;
            c|customDataFile)
                customDataFile=$OPTARG
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

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$resourceGroupLocation" ] || [ -z "$storageNamePrefix" ] || [ -z "$adminUserName" ] || [ -z "$sshPublicKeyFile" ]; then
	echo "One or more of the required parameters is not provided"
    exit 1;
fi

#create the agent vm
agentNicName="swarm-agent-$agentIndex-nic"
masterLbName="swarm-agent-lb"
vnetName="swarm-vnet"
agentSubnetName="swarm-vnet-subnet-agent"
agentLbBEAddressPoolName="swarm-agent-lb-be-ap"
azure network nic create --resource-group $resourceGroupName --location $resourceGroupLocation --name $agentNicName \
    --subnet-vnet-name $vnetName --subnet-name $agentSubnetName \
    --lb-address-pool-ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/loadBalancers/$agentLbName/backendAddressPools/$agentLbBEAddressPoolName"
    
agentVmName="swarm-agent-$agentIndex"
azure vm create --resource-group $resourceGroupName --location $resourceGroupLocation --name $agentVmName \
    --vnet-name $vnetName --vnet-subnet-name $agentSubnetName --nic-name $agentNicName \
     --availset-name "swarm-agent-avset" \
     --storage-account-name $storageNamePrefix"s02" --storage-account-type Standard_LRS \
     --vm-size Standard_D1_v2 --os-type Linux --image-urn Canonical:UbuntuServer:16.04.0-LTS:16.04.201610200 \
     --admin-username $adminUserName --ssh-publickey-file $sshPublicKeyFile \
     --custom-data $customDataFile
