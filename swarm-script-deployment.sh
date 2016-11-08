#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

i=$(($# + 1)) # index of the first non-existing argument
declare -A longoptspec
longoptspec=( [subscriptionId]=1 [resourceGroupName]=1 [resourceGroupLocation]=1 [domainPrefix]=1 [adminUserName]=1 [sshPublicKeyFile]=1 [storageNamePrefix]=1 )
optspec=":s:g:l:d:u:k:t:-:"
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
            d|domainPrefix)
                domainPrefix=$OPTARG
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

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$resourceGroupLocation" ] || [ -z "$domainPrefix" ] || [ -z "$storageNamePrefix" ] || [ -z "$adminUserName" ] || [ -z "$sshPublicKeyFile" ]; then
	echo "One or more of the required parameters is not provided"
    exit 1;
fi

#switch the mode to azure resource manager
azure config mode arm

#select the subscription
azure account set $subscriptionId

#create the resource group
azure group create --name $resourceGroupName --location $resourceGroupLocation

#create the virtual network
vnetName="swarm-vnet"
azure network vnet create --resource-group $resourceGroupName --name $vnetName --location $resourceGroupLocation --address-prefixes "172.16.0.0/16"

#create the master subnet
masterSubnetName="swarm-vnet-subnet-master"
azure network vnet subnet create --resource-group $resourceGroupName --vnet-name $vnetName --name $masterSubnetName --address-prefix "172.16.0.0/24"

#create the master public ip with DNS set to <domainPrefix>-master.<location>.cloudapp.azure.com
masterPublicIpName="swarm-master-pip"
azure network public-ip create --resource-group $resourceGroupName --name $masterPublicIpName --location $resourceGroupLocation --domain-name-label "$domainPrefix-master" --allocation-method Dynamic

#create the master loadbalancer
masterLbName="swarm-master-lb"
azure network lb create --resource-group $resourceGroupName --location $resourceGroupLocation --name $masterLbName
masterLbFrontendName="swarm-master-lb-frontend"
azure network lb frontend-ip create --resource-group $resourceGroupName --lb-name $masterLbName --name $masterLbFrontendName --public-ip-name $masterPublicIpName
masterLbBEAddressPoolName="swarm-master-lb-be-ap"
azure network lb address-pool create --resource-group $resourceGroupName --lb-name $masterLbName --name $masterLbBEAddressPoolName

#create the master-1 vm
azure network lb inbound-nat-rule create --resource-group $resourceGroupName --lb-name $masterLbName --name ssh1 --protocol tcp --frontend-port 20022 --backend-port 22
master1NicName="swarm-master-1-nic"
azure network nic create --resource-group $resourceGroupName --location $resourceGroupLocation --name $master1NicName \
    --subnet-vnet-name $vnetName --subnet-name $masterSubnetName \
    --lb-address-pool-ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/loadBalancers/$masterLbName/backendAddressPools/$masterLbBEAddressPoolName" \
    --lb-inbound-nat-rule-ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/loadBalancers/$masterLbName/inboundNatRules/ssh1" \
    --private-ip-address 172.16.0.5
master1VmName="swarm-master-1"
azure vm create --resource-group $resourceGroupName --location $resourceGroupLocation --name $master1VmName \
    --vnet-name $vnetName --vnet-subnet-name $masterSubnetName --nic-name $master1NicName \
     --availset-name "swarm-master-avset" \
     --storage-account-name $storageNamePrefix"s01" --storage-account-type Standard_LRS \
     --vm-size Standard_D1_v2 --os-type Linux --image-urn Canonical:UbuntuServer:16.04.0-LTS:16.04.201610200 \
     --admin-username $adminUserName --ssh-publickey-file $sshPublicKeyFile

#create the agent subnet
agentSubnetName="swarm-vnet-subnet-agent"
azure network vnet subnet create --resource-group $resourceGroupName --vnet-name $vnetName --name $agentSubnetName --address-prefix "172.16.1.0/24"

#create the agent public ip with DNS set to <domainPrefix>-agent.<location>.cloudapp.azure.com
agentPublicIpName="swarm-agent-pip"
azure network public-ip create --resource-group $resourceGroupName --name $agentPublicIpName --location $resourceGroupLocation --domain-name-label "$domainPrefix-agent" --allocation-method Dynamic

#create the agent loadbalancer
agentLbName="swarm-agent-lb"
azure network lb create --resource-group $resourceGroupName --location $resourceGroupLocation --name $agentLbName
agentLbFrontendName="swarm-agent-lb-frontend"
azure network lb frontend-ip create --resource-group $resourceGroupName --lb-name $agentLbName --name $agentLbFrontendName --public-ip-name $agentPublicIpName
agentLbBEAddressPoolName="swarm-agent-lb-be-ap"
azure network lb address-pool create --resource-group $resourceGroupName --lb-name $agentLbName --name $agentLbBEAddressPoolName
agentLbHttpProbeName="swarm-agent-lb-http-probe"
azure network lb probe create --resource-group $resourceGroupName --lb-name $agentLbName --name $agentLbHttpProbeName --protocol TCP --port 80
agentLbHttpRuleName="swarm-agent-lb-http"
azure network lb rule create --resource-group $resourceGroupName --lb-name $agentLbName --name $agentLbHttpRuleName \
    --protocol TCP --frontend-port 80 --backend-port 80 --probe-name $agentLbHttpProbeName \
    --frontend-ip-name  $agentLbFrontendName --backend-address-pool-name $agentLbBEAddressPoolName  

#create the agent-1 vm
agent1NicName="swarm-agent-1-nic"
azure network nic create --resource-group $resourceGroupName --location $resourceGroupLocation --name $agent1NicName \
    --subnet-vnet-name $vnetName --subnet-name $agentSubnetName \
    --lb-address-pool-ids "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/loadBalancers/$agentLbName/backendAddressPools/$agentLbBEAddressPoolName"
    
agent1VmName="swarm-agent-1"
azure vm create --resource-group $resourceGroupName --location $resourceGroupLocation --name $agent1VmName \
    --vnet-name $vnetName --vnet-subnet-name $agentSubnetName --nic-name $agent1NicName \
     --availset-name "swarm-agent-avset" \
     --storage-account-name $storageNamePrefix"s02" --storage-account-type Standard_LRS \
     --vm-size Standard_D1_v2 --os-type Linux --image-urn Canonical:UbuntuServer:16.04.0-LTS:16.04.201610200 \
     --admin-username $adminUserName --ssh-publickey-file $sshPublicKeyFile