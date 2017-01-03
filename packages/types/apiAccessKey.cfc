component extends="farcry.core.packages.types.types" displayName="API Access Key" {

	property name="title" type="string"
			 ftSeq="1" ftFieldSet="Access Key" ftLabel="Title"
			 ftHint="Reference label for key";

	property name="bActive" type="boolean" dbIndex="accesskey:2,accesskeyid:2" default="1" ftDefault="1"
			 ftSeq="2" ftFieldSet="Access Key" ftLabel="Active"
			 ftHint="Only active keys can be used for authentication.";

	property name="accessKeyID" type="string" dbIndex="accesskeyid:1"
			 ftSeq="3" ftFieldSet="Access Key" ftLabel="ID"
			 ftDisplayOnly="true"
			 ftHint="This value is used as the user ID and for HMAC authentication. This will be set automatically when the key is created.";

	property name="accessKeySecret" type="string"
			 ftSeq="4" ftFieldSet="Access Key" ftLabel="Secret"
			 ftHint="This value is used for HMAC authentication. This will be set automatically on save if empty.";

	property name="accessKey" type="string" dbIndex="accesskey:1"
			 ftSeq="5" ftFieldSet="Access Key" ftLabel="Key"
			 ftHint="This value is used for key authentication. This will be set automatically on save if empty.";

	property name="authorization" type="longchar" ftDefault="{}"
			 ftSeq="6" ftFieldSet="Access Key" ftLabel="Authorization" ftOperations="list,get"
			 ftHint="The operations that this key is authorized to access.";


	public struct function getByID(required string id) {
		var q = application.fapi.getContentObjects(typename="apiAccessKey", accessKeyID_eq=arguments.id, bActive_eq=1);

		if (q.recordcount) {
			return getData(objectid=q.objectid);
		}
		else {
			return {};
		}
	}

	public struct function getByKey(required string key) {
		var q = application.fapi.getContentObjects(typename="apiAccessKey", accessKey_eq=arguments.key, bActive_eq=1);

		if (q.recordcount) {
			return getData(objectid=q.objectid);
		}
		else {
			return {};
		}
	}

	public string function signKey(required string stringToSign, required string secret) {
		return lcase(
			binaryEncode(
				application.fc.lib.cdn.cdns.s3.HMAC_SHA256(
					arguments.stringToSign,
					arguments.secret.getBytes("UTF8")
				),
				'hex'
			)
		);
	}

	public struct function setData(required struct stProperties, string user="", string auditNote="Updated", boolean bAudit=true, string dsn=application.dsn, boolean bSessionOnly=false, boolean bAfterSave=true, boolean bSetDefaultCoreProperties=true, string previousStatus) {
		if (not arguments.bSessionOnly) {
			if (structKeyExists(arguments.stProperties, "accessKeyID") and not len(arguments.stProperties.accessKeyID)) {
				arguments.stProperties.accessKeyID = randomString(size=10, pool="0123456789");
			}
			if (structKeyExists(arguments.stProperties, "accessKey") and not len(arguments.stProperties.accessKey)) {
				arguments.stProperties.accessKey = randomString(size=32, pool="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz");
			}
			if (structKeyExists(arguments.stProperties, "accessKeySecret") and not len(arguments.stProperties.accessKeySecret)) {
				arguments.stProperties.accessKeySecret = randomString(size=250, pool="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz");
			}
		}

		return super.setData(argumentCollection=arguments);
	}

	public string function randomString(numeric size=10, string pool="0123456789") {
		var result = "";
		var i = 0;

		for (i=0; i<arguments.size; i++) {
			result &= mid(arguments.pool, randRange(1, len(arguments.pool)), 1);
		}

		return result;
	}

	public string function ftEditAuthorization(required struct stObject, required struct stMetadata, required string typename, string inputClass="") {
		var html = "";
		var stAuth = {};
		var types = listToArray(application.fapi.getConfig("api", "contentTypes", ""));
		var typename = {};
		var op = "";

		if (len(arguments.stMetadata.value) and isJSON(arguments.stMetadata.value)) {
			stAuth = deserializeJSON(arguments.stMetadata.value);
		}

		html = "<table class='table'><thead><tr><th>Type</th><th>List</th><th>Get</th><th>Create</th><th>Update</th><th>Delete</th></tr></thead><tbody>";

		for (typename in types) {
			if (not structKeyExists(stAuth, typename)) {
				stAuth[typename] = {};
			}

			html &= "<tr><th>#application.fapi.getContentTypeMetadata(typename=typename, md="displayName", defualt=typename)#</th>";
			for (op in ["list", "get", "create", "update", "delete"]) {
				if (not structKeyExists(stAuth[typename], op)) {
					stAuth[typename][op] = false;
				}
				html &= "<td><input type='checkbox' value='1' " & (stAuth[typename][op] ? "checked" : "") & " onChange='inp=document.getElementById(""#arguments.fieldname#""); stAuth=JSON.parse(inp.value); stAuth.#typename#.#op#=this.checked; inp.value=JSON.stringify(stAuth);'></td>";
			}
			html &= "</tr>";
		}

		html &= "</tbody></table><input type='hidden' name='#arguments.fieldname#' id='#arguments.fieldname#' value='#serializeJSON(stAuth)#'>";

		return html;
	}

}