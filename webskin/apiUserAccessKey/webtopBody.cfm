<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<ft:objectadmin 
	typename="apiUserAccessKey"
	title="UserAPI Access Key Administration"
	columnList="userID,device,bActive,accessKeyID,datetimelastCreated,datetimelastUpdated"
	sortableColumns="userID,device,bActive,accessKeyID,datetimelastCreated,datetimelastUpdated"
	lFilterFields="userID,device,accessKeyID"
	sqlorderby="datetimelastUpdated desc" />

<cfsetting enablecfoutputonly="false">