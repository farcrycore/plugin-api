<cfsetting enablecfoutputonly="true">

<cfset qErrorCodes = application.fc.lib.api.getErrorCodes() />

<cfoutput>
The #application.fapi.getConfig("general", "sitetitle")# API provides access
to data from the website.

#### Authentication

The following authentication methods are supported:

</cfoutput>

<cfif listFindNoCase(application.fapi.getConfig("api", "authentication"), "public")>
	<cfoutput>- No authentication - this API is accessible to the public.
</cfoutput>
</cfif>
<cfif listFindNoCase(application.fapi.getConfig("api", "authentication"), "key")>
	<cfoutput>- API key - include the API key in the request `Authentication` header.
</cfoutput>
</cfif>
<cfif listFindNoCase(application.fapi.getConfig("api", "authentication"), "basic")>
	<cfoutput>- Basic HTTP - pass your FarCry credentials with the request in the `Authentication` header.
</cfoutput>
</cfif>
<cfif listFindNoCase(application.fapi.getConfig("api", "authentication"), "session")>
	<cfoutput>- Session - if you have logged into the webtop, the browser session will authenticate you automatically.
</cfoutput>
</cfif>

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