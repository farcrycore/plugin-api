<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<ft:objectadmin 
	typename="apiUserAccessKey"
	title="API User Access Key Administration"
	columnList="userID,device,bActive,accessKeyID,datetimecreated,datetimelastupdated"
	sortableColumns="userID,device,bActive,accessKeyID,datetimecreated,datetimelastupdated"
	lFilterFields="userID,device,accessKeyID"
	sqlorderby="datetimelastupdated desc" />

<cfsetting enablecfoutputonly="false">