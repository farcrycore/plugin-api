<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<ft:objectadmin 
	typename="apiAccessKey"
	title="API Access Key Administration"
	columnList="title,bActive,accessKeyID,datetimecreated,datetimelastupdated"
	sortableColumns="title,bActive,accessKeyID,datetimecreated,datetimelastupdated"
	lFilterFields="title,accessKeyID"
	sqlorderby="datetimelastupdated desc" />

<cfsetting enablecfoutputonly="false">