<cfsetting enablecfoutputonly="true">

<cfset application.fc.lib.api.initializeAPIs() />
<cfset apis = application.fc.lib.api.getAPIs() />

<cfparam name="url.api" default="#apis[1].id#">

<cfset aAPIs = [] />
<cfloop array="#apis#" index="thisapi">
  <cfset arrayAppend(aAPIs, {
    "url": thisapi.swagger,
    "name": thisapi.label
  }) />
	<cfif url.api eq thisapi.id>
		<cfset currentAPI = thisapi />
	</cfif>
</cfloop>

<cfoutput>
<!-- HTML for static distribution bundle build -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="./swagger-ui.css" >
    <link rel="icon" type="image/png" href="./favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="./favicon-16x16.png" sizes="16x16" />
    <style>
      html
      {
        box-sizing: border-box;
        overflow: -moz-scrollbars-vertical;
        overflow-y: scroll;
      }

      *,
      *:before,
      *:after
      {
        box-sizing: inherit;
      }

      body
      {
        margin:0;
        background: ##fafafa;
      }
    </style>
  </head>

  <body>
    <div id="swagger-ui"></div>

    <script src="./swagger-ui-bundle.js"> </script>
    <script src="./swagger-ui-standalone-preset.js"> </script>
    <script>
    window.onload = function() {

      // Build a system
      const ui = SwaggerUIBundle({
        urls: #serializeJSON(aAPIs)#,
        "urls.primaryName": #serializeJSON(currentAPI.label)#,
        docExpansion: "none",
        dom_id: '##swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl,
          SwaggerUIBundle.plugins.Topbar,
          function (system) {
            window.configSystem = system;
            return {
              statePlugins: {
                auth: {
                  wrapActions: {
                    authorize: function(oriAction, system) {
                      return function(a) {
                        var r = oriAction(a);
                        system.specActions.download();
                        return r;
                      }
                    }
                  }
                }
              }
            }
          }
        ],
        requestInterceptor: function(e) {
          var token = window.configSystem.auth().getIn(["authorized"]);
          if (token != null && e.headers.authorization == null) {
            if (j.api_key)
              e.headers[j.api_key.schema.name] = j.api_key.value;
            if (j.basic)
              e.headers.Authorization = j.basic.value.header;
          }
          return e;
        },
        layout: "StandaloneLayout",
      })

      window.ui = ui
    }
  </script>
  </body>
</html>
</cfoutput>

<cfsetting enablecfoutputonly="false">