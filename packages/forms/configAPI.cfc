component extends="farcry.core.packages.forms.forms" key="api" fuAlias="api" displayName="API" hint="Access and authentication settings" {

	property name="authentication" type="string" ftDefault="basic,key,session"
			 ftSeq="1" ftFieldSet="Security" ftLabel="Authentication"
			 ftType="list" ftList="public:No authentication,basic:Basic HTTP (FarCry users),key:API Key,session:FarCry Session"
			 ftSelectMultiple="true";

	property name="contentTypes" type="longchar" ftDefault=""
			 ftSeq="2" ftFieldSet="Security" ftLabel="Content Types"
			 ftType="list" ftListData="getTypes" ftSelectMultiple="true";
property name="schemes" type="string" ftDefault="http"
			 ftSeq="10" ftFieldSet="URL" ftLabel="Scheme"
			 ftType="list" ftList="http,https" ;

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
