<cfsetting enablecfoutputonly="true">

<cfset qErrorCodes = application.fc.lib.api.getErrorCodes() />

<cfoutput>
The #application.fapi.getConfig("general", "sitetitle")# API provides access
to data from the website.

#### Authentication
</cfoutput>

<cfswitch expression="#application.fapi.getConfig("api", "authentication")#">
	<cfcase value="public"><cfoutput>No authentication is required.</cfoutput></cfcase>
	<cfcase value="key"><cfoutput>All requests should include your API key in the `Authentication` header.</cfoutput></cfcase>
	<cfcase value="basic"><cfoutput>All requests should include basic HTTP authentication, providing your FarCry credentials.</cfoutput></cfcase>
</cfswitch>

<cfoutput>
#### Errors

Errors may be returned by the API, typically because the API request was
not valid. In these cases an error JSON object will be returned instead
of the standard API response. The error response contains an error code
and a user readable message.
</cfoutput>

<cfoutput query="qErrorCodes" group="type">
###### #qErrorCodes.type#

#qErrorCodes.typeHint#

| Code | Message | Notes |
| ---- | ------- | ----- |
<cfoutput>| #qErrorCodes.code# | #qErrorCodes.message# | Response will be #qErrorCodes.status#. |
</cfoutput>
</cfoutput>

<cfsetting enablecfoutputonly="false">