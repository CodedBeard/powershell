# Create Remote Desktop Sesson Collection deployment

This template deploys the following resources:

<ul><li>storage account;</li><li>RD Gateway/RD Web Access vm;</li><li>RD Connection Broker/RD Licensing Server vm;</li><li>a number of RD Session hosts (number defined by 'numberOfRdshInstances' parameter)</li></ul>

The template will use existing DC, join all vms to the domain and configure RDS roles in the deployment.

Click the button below to deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCodedBeard%2Fpowershell%2Fmaster%2FAzure-ARM%2FRDS-ExistingAD-ExistingNetwork%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FCodedBeard%2Fpowershell%2Fmaster%2FAzure-ARM%2FRDS-ExistingAD-ExistingNetwork%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>