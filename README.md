# Docker Swarm mode Cluster (1.12)

## NOTES. Please read before continue!

> :warning: **NOTE:** This is not the official Docker for Azure template (currently in private beta). If you're interested in that, please go to Docker, Inc. website: https://beta.docker.com/docs/azure/ 

> :warning: **NOTE:** This template does not use Azure Container Service features. You can learn more about that on the official Azure documentation: https://azure.microsoft.com/en-us/documentation/services/container-service/

## Disclaimer

This template deploys a [Docker Swarm](https://docs.docker.com/engine/swarm/) cluster on
Azure with 1,3 or 5 Swarm managers and specified number of Swarm workers in a Virtual Machine Scale Set using Ubuntu Linux as the host operating system.

> If you are not familiar with Docker Swarm, please [read Swarm documentation](https://docs.docker.com/engine/swarm/). 

## SSH Key Generation
You will need an SSH RSA key for access! You can use `ssh-keygen` command on Linux/Mac or **PuTTY** to create public
and private key pairs. The `sshPublicKey` argument should be contents of the public key file you have.

## Cluster Properties

TBD

## Connecting the Cluster

TBD