component extends="farcry.core.packages.forms.forms" key="api" fuAlias="api" displayName="API" hint="Access and authentication settings" {

	property name="authentication" type="string" ftDefault="basic,key,session"
			 ftSeq="1" ftFieldSet="Security" ftLabel="Authentication"
			 ftType="list" ftListData="getAuthenticationMethods"
			 ftSelectMultiple="true";

	property name="contentTypes" type="longchar" ftDefault=""
			 ftSeq="2" ftFieldSet="Security" ftLabel="Content Types"
			 ftType="list" ftListData="getTypes" ftSelectMultiple="true";

	property name="schemes" type="string" ftDefault="http"
			 ftSeq="10" ftFieldSet="URL" ftLabel="Scheme"
			 ftType="list" ftList="http,https" ;

	property name="secret" type="string" ftDefault=""
			 ftSeq="11" ftFieldSet="Statelss API Key" ftLabel="Secret"
			 ftHint="This secret is used for signing stateless API keys";

	property name="statelessKeyExpiry" type="integer" ftDefault="3600"
			 ftSeq="12" ftFieldSet="Statelss API Key" ftLabel="Expiry"
			 ftHint="How long stateless keys should be valid for";

	public query function getAuthenticationMethods() {
		var qMethods = queryNew("value,name");
		var authMethods = application.fc.lib.api.getAuthenticationMethods();

		for (var i=1; i<=arrayLen(authMethods); i++) {
			queryAddRow(qMethods, {
				value = authMethods[i].key,
				name = authMethods[i].label
			});
		}

		return qMethods;
	}

	public query function getTypes() {
		var qTypes = querynew("value,name");
		var typename = "";
		var q = "";

		for (typename in application.stCOAPI) {
			if (application.fapi.getContentTypeMetadata(typename=typename, md="class", default="ignore") eq "type" and not application.fapi.getContentTypeMetadata(typename=typename, md="bSystem", default=false)) {
				queryAddRow(qTypes);
				querySetCell(qTypes, "value", typename);
				querySetCell(qTypes, "name", application.fapi.getContentTypeMetadata(typename=typename, md="displayName", default=typename));
			}
		}

		q = new Query(
			sql = "SELECT * FROM qTypes ORDER BY name ASC",
			dbtype = "query",
			qTypes = qTypes
		);

		return q.execute().getResult();
	}

	public struct function process(required struct fields) {
		application.fc.lib.api.initializeAPIs(bFlush=true);

		return arguments.fields;
	}

}
