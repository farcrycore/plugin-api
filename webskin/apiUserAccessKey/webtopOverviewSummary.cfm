<cfsetting enablecfoutputonly="true">


<!--- import tag libraries --->
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/navajo" prefix="nj" />


<!--- 
 // view 
--------------------------------------------------------------------------------->
<skin:view stObject="#stObj#" webskin="webtopOverviewDevActions" />

<cfset stUser = application.fapi.getContentObject(typename="dmProfile", objectid=stObj.userID) />

<ft:fieldset legend="#application.fapi.getContentTypeMetadata(stobj.typename,'displayname',stobj.typename)# Information">
	<ft:field label="User">
		<cfoutput>#stUser.label#</cfoutput>
	</ft:field>

	<ft:field label="Device">
		<cfoutput>#stObj.device#</cfoutput>
	</ft:field>

	<ft:field label="Active" bMultiField="true">
		<cfif stObj.bActive>
			<cfoutput>Yes</cfoutput>
		<cfelse>
			<cfoutput>No</cfoutput>
		</cfif>
	</ft:field>

	<ft:field label="Access ID" bMultiField="true">
		<cfoutput><code>#stObj.accessKeyID#</code></cfoutput>
	</ft:field>

	<ft:field label="Access Secret" bMultiField="true">
		<cfoutput><code>#stObj.accessKeySecret#</code></cfoutput>
	</ft:field>

	<ft:field label="Access Key" bMultiField="true">
		<cfoutput><code>userkey:#stObj.accessKey#</code></cfoutput>
	</ft:field>
</ft:fieldset>


<cfsetting enablecfoutputonly="false">