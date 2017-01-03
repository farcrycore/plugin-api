<cfsetting enablecfoutputonly="true">


<!--- import tag libraries --->
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/navajo" prefix="nj" />


<!--- 
 // view 
--------------------------------------------------------------------------------->
<skin:view stObject="#stObj#" webskin="webtopOverviewDevActions" />


<ft:fieldset legend="#application.fapi.getContentTypeMetadata(stobj.typename,'displayname',stobj.typename)# Information">
	<ft:field label="Title">
		<cfoutput>#stObj.title#</cfoutput>
	</ft:field>

	<ft:field label="Active" bMultiField="true">
		<cfif stObj.bActive>
			<cfoutput>Yes</cfoutput>
		<cfelse>
			<cfoutput>No</cfoutput>
		</cfif>
	</ft:field>

	<ft:field label="Access ID" bMultiField="true">
		<cfoutput>#stObj.accessKeyID#</cfoutput>
	</ft:field>

	<ft:field label="Access Secret" bMultiField="true">
		<cfoutput>#stObj.accessKeySecret#</cfoutput>
	</ft:field>

	<ft:field label="Access Key" bMultiField="true">
		<cfoutput>#stObj.accessKey#</cfoutput>
	</ft:field>
</ft:fieldset>


<cfsetting enablecfoutputonly="false">