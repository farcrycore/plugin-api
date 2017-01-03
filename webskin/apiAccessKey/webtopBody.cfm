<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<ft:objectadmin 
	typename="apiAccessKey"
	title="API Access Key Administration"
	columnList="title,bActive,accessKeyID,datetimelastCreated,datetimelastUpdated"
	sortableColumns="title,bActive,accessKeyID,datetimelastCreated,datetimelastUpdated"
	lFilterFields="title,accessKeyID"
	sqlorderby="datetimelastUpdated desc" />

<cfsetting enablecfoutputonly="false">