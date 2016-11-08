#! /usr/bin/env node
var template = require('./swarm-deployment.json');
var fs = require('fs');

template.variables.masterCustomData = new Buffer(fs.readFileSync('./master-cloud-config.yaml', 'UTF-8')).toString("base64"); 
template.variables.agentCustomData = new Buffer(fs.readFileSync('./agent-cloud-config.yaml', 'UTF-8')).toString("base64");	
var templateFile = fs.createWriteStream('./swarm-deployment.json');
templateFile.write(JSON.stringify(template, null, 4));
templateFile.end();
