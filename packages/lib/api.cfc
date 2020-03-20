component {

	// NOTE: cases where more than one error is returned will always be all 401 Unauthorized, or 500 Internal Server Error
	this.codeTypeHints = [{
		"title" = "0xx API",
		"hint" = "Error codes begining with `0` will always be basic errors accessing the API.",
		"codes" = ["001","002","003","004","005"]
	},{
		"title" = "1xx Authorization",
		"hint" = "Error codes begining with `1` will always be authorization errors.",
		"codes" = ["101","102","103","104","105"]
	},{
		"title" = "2xx Request",
		"hint" = "Error codes beginning with `2` will always be request validation errors. Responses will be `400 Bad Request`.",
		"codes" = ["201","202","203"]
	},{
		"title" = "999 Unknown",
		"hint" = "If we generate an unexpected error, we will return an error with this code, as well as logging it internally. Response will be `500 Internal Server Error`.",
		"codes" = ["999"]
	}];
	this.codes = {
		// basic request errors
		"001" = { "message"="Request does not match a valid endpoint", "status"="404 Not Found", "type"="0xx API" },
		"002" = { "message"="This endpoint does not support that HTTP method", "status"="405 Method Not Allowed", "type"="0xx API" },
		"003" = { "message"="This API does not support the requested Accept headers", "status"="406 Not Acceptable", "type"="0xx API" },
		"004" = { "message"="This API does not support the provided content-type", "status"="415 Unsupported Media Type", "type"="0xx API" },
		"005" = { "message"="This API does not allow requests from that Origin", "status"="403 Forbidden", "type"="0xx API" },

		// security errors
		"101" = { "message"="Invalid credentials", "status"="401 Unauthorized", "type"="1xx Authorization" },
		"102" = { "message"="Missing Date or Timestamp header", "status"="401 Unauthorized", "type"="1xx Authorization" },
		"103" = { "message"="Timestamp was too far from server time", "status"="401 Unauthorized", "type"="1xx Authorization" },
		"104" = { "message"="Authorization signature did not match", "status"="401 Unauthorized", "type"="1xx Authorization" },
		"105" = { "message"="User is not authorized for this request", "status"="401 Unauthorized", "type"="1xx Authorization" },

		// parameter validation errors
		"201" = { "message"="Missing required parameter", "status"="400 Bad Request" },
		"202" = { "message"="Invalid value", "status"="400 Bad Request" },
		"203" = { "message"="Requested object does not exist.", "status"="404 Not Found" },

		// unexpected errors
		"999" = { "status"="500 Internal Server Error" }
	};
	this.resources = {};
	this.handlers = [];
	this.swagger = {};
	this.apiPrefix = "/api";
	this.apis = {};
	this.apiList = [];
	this.acceptedResponseTypes = {
		"html" = ["text/html"],
		"json" = ["text/json","application/json"]
	};
	this.requestProcessors = ["addHeadFlag","addCORS","addHandler","addResponseType","addContent","addParameters","addAuthentication","addAuthorization","addPreprocessedParameters","executeEndpointFunction"];

	this.originWhitelist = ["*"];
	this.originWhitelistRegex = [];


	public any function init(){
		var domain = "";
		var type = "";
		var typeVal = "";

		for (domain in this.originWhitelist) {
			if (domain neq "*") {
				arrayAppend(this.originWhitelistRegex, createObject("java", "java.util.regex.Pattern").compile( javaCast( "string", domain ) ));
			}
		}

		return this;
	}

	public void function initializeAPIs(boolean bFlush=false) {
		var stMD = {};
		var utils = createobject("component","farcry.core.packages.farcry.utils");
		var apis = listToArray(utils.getComponents("api"));
		var apiname = "";
		var o = "";
		var swagger = isDefined("application.fc.lib.swagger") ? application.fc.lib.swagger : createobject("component", "swagger");

		if (not arguments.bFlush and not structIsEmpty(this.apis)) {
			return;
		}

		this.oAccessKey = application.fapi.getContentType(typename="apiAccessKey");

		for (apiname in apis){
			if (apiname neq "base") {
				o = createObject("component", utils.getPath("api", apiname));
				stMD = getMetadata(o);

				if (structKeyExists(stMD, "disabled")) {
					continue;
				}

				if (structKeyExists(stMD, "displayName")) {
					arrayAppend(this.apiList, { "id"=apiname, "label"=stMD.displayName, "swagger"=this.apiPrefix & "/" & apiname & "/swagger" });
				}
				else {
					arrayAppend(this.apiList, { "id"=apiname, "label"=apiname, "swagger"=this.apiPrefix & "/" & apiname & "/swagger" });
				}

				if (structkeyexists(o, "init")) {
					o.init();
				}

				this.apis[apiname] = o;
				this.swagger[apiname] = swagger.getSwaggerAPI(metadata=stMD, prefix=this.apiPrefix & "/" & apiname, typenames=listToArray(application.fapi.getConfig("api", "contentTypes", "")));
				addHandlers(name=apiname, metadata=stMD);
			}
		}
	}

	public void function updateAuthorization(required struct auth) {
		
	}

	public string function getStatelessAPIKey(required string username, numeric expiry=application.fapi.getConfig("api", "statelessKeyExpiry")) {
		var stProfile = application.fapi.getContentType("dmProfile").getProfile(arguments.username);
		var expiryTime = round(getTickCount() / 1000) + arguments.expiry;
		var stringToSign = stProfile.objectid & ":" & numberFormat(expiryTime, "0");
		var secret = application.fapi.getConfig("api", "secret");
		var encryptedSignature = lcase(binaryEncode(application.fc.lib.cdn.cdns.s3.HMAC_SHA256(stringToSign, secret.getBytes("UTF8")), 'hex'));

		return stringToSign & ":" & encryptedSignature;
	}

	public array function getAPIs() {
		return this.apiList;
	}

	public void function addHandlers(required string name, required struct metadata) {
		var stHandler = {};
		var method = "";
		var path = {};
		var i = 0;
		var func = {};

		if (not structKeyExists(arguments.metadata, "functions")) {
			return;
		}

		for (func in arguments.metadata.functions) {
			if (structKeyExists(func, "handle")) {
				method = listFirst(func.handle, " ");
				path = this.apiPrefix & "/" & arguments.name & listRest(func.handle, " ");

				stHandler = {
					"api" = arguments.name,
					"function" = func.name,
					"method" = lcase(listFirst(func.handle, " ")),
					"parts" = {},
					"parameters" = [],
					"path" = path,
					"permission" = structKeyExists(func, "permission") ? func.permission : "public",
					"attrs" = duplicate(func),
					"preprocessing" = []
				};

				if (structKeyExists(func, "parameters") and arrayLen(func.parameters)) {
					for (i in func.parameters) {
						if (structKeyExists(i, "in") and i.in eq "pre") {
							arrayAppend(stHandler.preprocessing, getPreprocessingParameter(i));
						}
						else {
							arrayAppend(stHandler.parameters, application.fc.lib.swagger.getSwaggerParameter(i));
						}
					}
				}

				stHandler["regex"] = "^" & rereplace(path, '\{[^\}]+\}', '[^\/]+', 'ALL') & "$";
				stHandler["java_regex"] = createObject("java", "java.util.regex.Pattern").compile( javaCast( "string", stHandler.regex ) );

				for (i=1; i<=listLen(path, "/"); i++) {
					if (reFind("^\{[\w_]+\}$", listGetAt(path, i, "/"))) {
						stHandler.parts[reReplace(listGetAt(path, i, "/"), "^\{([^\}]+)\}$", "\1")] = i;
					}
				}

				arrayAppend(this.handlers, stHandler);
			}
		}

		if (structKeyExists(arguments.metadata, "extends")) {
			addHandlers(metadata=arguments.metadata.extends, argumentCollection=arguments);
		}
	}

	public struct function getPreprocessingParameter(required struct metadata) {
		var paramOut = {
			"name" = arguments.metadata.name,
			"description" = structKeyExists(arguments.metadata, "description") ? arguments.metadata.description : "",
			"method" = listFirst(arguments.metadata.fn, "("),
			"args" = {}
		};

		if (refind("\([^\)]", arguments.metadata.fn)) {
			// parse out args
			var theseargs = mid(arguments.metadata.fn, find("(",arguments.metadata.fn)+1, find(")",arguments.metadata.fn)-find("(",arguments.metadata.fn)-1);
			var arg = "";

			for (arg in listToArray(theseargs)) {
				paramOut.args[trim(listFirst(arg, "="))] = listRest(arg, "=");
			}
		}

		return paramOut;
	}

	// parse every request into a self contained data packet
	public void function handleRequest(){
		var processor = "";
		var error_code = "";
		var error_codes = [];

		if (structIsEmpty(this.apis)) {
			initializeAPIs();
		}

		request.res = createResponse();
		request.req = createRequest();

		try {
			// each addXxx function checks the request to add information to the req
			// object if it is valid and return errors if it is not
			for (processor in this.requestProcessors) {
				error_codes = invoke(this, processor, {req=request.req, res=request.res});
				if (arrayLen(error_codes)) { // handles 201 and 202 error cases
					for (error_code in error_codes) {
						addError(req=request.req, res=request.res, argumentCollection=error_code);
					}
					sendResponse(req=request.req, res=request.res);
					return;
				}
			}
		} catch (any e) {
			application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
			addError(req=request.req, res=request.res, code="999", message=len(e.message)?e.message:e.detail, debug=application.fc.lib.error.normalizeError(e));
		}

		sendResponse(req=request.req, res=request.res);
	}

	public struct function createResponse() {
		return {
			"start" = getTickCount(),
			"status" = "200 Ok",
			"content" = {},
			"errors" = [],
			"headers" = {}
		};
	}

	public struct function createRequest() {
		var requestData = getHTTPRequestData();
		var key = "";
		var req = {
			"accept" = "",
			"method" = requestData.method,
			"url" = "",
			"query_params" = {},
			"query_string" = "",
			"headers" = duplicate(requestData.headers),
			"content_string" = requestData.content,
			"content" = {},
			"form" = duplicate(form)
		};
		var qs = [];

		// pull out the interesting query variables
		for (key in url){
			switch (key){
				case "furl":
					req["url"] = url.furl;
					if (right(req["url"], 1) eq "/")
						req["url"] = left(req["url"], len(req["url"])-1);
					break;
				case "__allowredirect": case "updateapp":
					break;
				default:
					req.query_params[key] = url[key];
					break;
			}
		}

		// construct a consistent query string
		for (key in listToArray(listSort(lcase(structKeyList(req.query_params)), "text"))) {
			arrayAppend(qs, "#urlEncodedFormat(key)#=#urlEncodedFormat(req.query_params[key])#");
		}
		req.query_string = arrayToLIst(qs, "&");

		// various helpful conversions
		if (structKeyExists(req.headers, "Date")) {
			req.timestamp = round(parseDateTime(req.headers.Date).getTime() / 1000);
		}
		else if (structKeyExists(req.headers, "Timestamp")) {
			req.timestamp = req.headers.timestamp;
		}

		return req;
	}

	public array function addHeadFlag(required struct req, required struct res) {
		arguments.req.clearResponse = false;

		if (arguments.req.method eq "HEAD") {
			arguments.req.method = "GET";
			arguments.req.clearResponse = true;
		}

		return [];
	}

	public array function addCORS(required struct req, required struct res) {
		var regex = "";

		if (arrayLen(this.originWhitelist) and this.originWhitelist[1] eq "*" and structKeyExists(arguments.req.headers, "Origin")) {
			arguments.res.headers["Access-Control-Allow-Origin"] = arguments.req.headers.Origin;
			arguments.res.headers["Access-Control-Allow-Headers"] = "cache-control,content-type,authorization";
			return [];
		}
		else if (arrayLen(this.originWhitelist) and this.originWhitelist[1] eq "*") {
			arguments.res.headers["Access-Control-Allow-Origin"] = "*";
			arguments.res.headers["Access-Control-Allow-Headers"] = "cache-control,content-type,authorization";
			return [];
		}
		else if (structKeyExists(arguments.req.headers, "Origin")) {
			for (regex in this.originWhitelistRegex) {
				if (regex.matcher(arguments.req.headers.Origin).matches()) {
					arguments.res.headers["Access-Control-Allow-Origin"] = arguments.req.headers.Origin;
					arguments.res.headers["Access-Control-Allow-Headers"] = "cache-control,content-type,authorization";
					return [];
				}
			}

			return [{"code"="005"}];
		}
	}

	public array function addHandler(required struct req, required struct res) {
		var handler = {};
		var allowed_methods = [];

		for (handler in this.handlers) {
			if (handler.java_regex.matcher( javaCast( "string", arguments.req.url ) ).matches()) {
				if (handler.method eq arguments.req.method) {
					arguments.req.handler = handler;
				}
				else if (structKeyExists(arguments.req.headers, "Access-Control-Request-Method") and handler.method eq arguments.req.headers["Access-Control-Request-Method"]) {
					arguments.req.handler = handler;
				}
				arrayAppend(allowed_methods, ucase(handler.method));
			}
		}

		if (structKeyExists(arguments.req, "handler")) {
			arguments.res.headers["Allow"] = arrayToList(allowed_methods, ", ");
			arguments.res.headers["Access-Control-Allow-Methods"] = arrayToList(allowed_methods, ", ");
			return [];
		}
		else if (arrayLen(allowed_methods)) {
			arguments.res.headers["Allow"] = arrayToList(allowed_methods, ", ");
			arguments.res.headers["Access-Control-Allow-Methods"] = arrayToList(allowed_methods, ", ");
			return [{"code"="002"}];
		}
		else {
			return [{"code"="001"}];
		}
	}

	public array function addResponseType(required struct req, required struct res) {
		var i = 0;
		if (structkeyexists(arguments.req.headers, "accept") and arguments.req.headers.accept neq "*/*"){
			arguments.req.headers.accept = replace(arguments.req.headers.accept, ";", ",", "ALL");

			for (i=1; i<=listlen(arguments.req.headers.accept); i++){
				switch (listgetat(arguments.req.headers.accept, i)){
					case "text/html":
						arguments.res["type"] = "html";
						break;
					case "json": case "text/json": case "application/json":
						arguments.res["type"] = "json";
						break;
				}
			}
			if (not structkeyexists(arguments.res, "type")){
				return [{"code"="003","detail"=arguments.req.headers.accept}];
			}
			else {
				return [];
			}
		}
		else {
			arguments.res["type"] = "json";
			return [];
		}
	}

	public array function addContent(required struct req) {
		// parse content
		if (structkeyexists(arguments.req.headers, "content-type")){
			arguments.req["content_type"] = arguments.req.headers["content-type"];
		}
		else {
			arguments.req.content_type = "";
		}

		if (len(arguments.req.content_string)) {
			arguments.req["content_md5"] = hash(arguments.req.content_string);
		}
		else {
			arguments.req["content_md5"] = "";
		}

		switch (listfirst(arguments.req.content_type, ";")){
			case "application/json": case "text/json":
				arguments.req["content"] = deserializeJSON(arguments.req.content_string);
				return [];
				break;
			default:
				if (len(arguments.req.content_string)) {
					return [{"code"="004"}];
				}
		}

		return [];
	}

	public array function addParameters(required struct req) {
		var parameter = {};
		var parameters = {};
		var path_parts = listToArray(arguments.req.url, "/");
		var errors = [];
		var i = 0;

		for (parameter in arguments.req.handler.parameters) {
			switch (parameter.in) {
			case "path":
				parameters[parameter.name] = path_parts[arguments.req.handler.parts[parameter.name]];
				break;
			case "query":
				if (structKeyExists(arguments.req.query_params, parameter.name)) {
					parameters[parameter.name] = arguments.req.query_params[parameter.name];
				}
				else if (parameter.required) {
					arrayAppend(errors, { "code"="201", "field"=parameter.name, "inp"=parameter["in"] });
				}
				break;
			case "header":
				if (structKeyExists(arguments.req.headers, parameter.name)) {
					parameters[parameter.name] = arguments.req.headers[parameter.name];
				}
				else if (parameter.required) {
					arrayAppend(errors, { code="201", "field"=parameter.name, "inp"=parameter["in"] });
				}
				break;
			case "body":
				parameters[parameter.name] = arguments.req.content;
				break;
			case "form":
				if (structKeyExists(arguments.req.form, parameter.name)) {
					parameters[parameter.name] = arguments.req.form[parameter.name];
				}
				else if (arguments.req.method neq "OPTIONS" and parameter.required) {
					arrayAppend(errors, { "code"="201", "field"=parameter.name, "inp"=parameter["in"] });
				}
				break;
			}

			if (structKeyExists(parameters, parameter.name)) {
				switch (parameter.type) {
				case "array":
					if (isSimpleValue(parameters[parameter.name])) {
						parameters[parameter.name] = listToArray(parameters[parameter.name]);
					}
					for (i=1; i<=arrayLen(parameters[parameter.name]); i++) {
						if (not isValid("uuid", parameters[parameter.name][i])) {
							arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="value at index #i-1# must be a valid UUID" });
						}
					}
					break;
				case "boolean":
					if (not isValid("boolean", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be boolean" });
					};
					break;
				case "datetime":
					if (not reFind("^\d{4}-\d{2}-\d{2}$", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be an RFC339 full-date string in the format YYYY-mm-dd" });
					}
					break;
				case "date":
					if (not reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be an RFC339 date-time string date in the format YYYY-mm-ddTHH:mm:ssZ" });
					}
					break;
				case "email":
					if (not isValid("email", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be a valid email address" });
					}
					break;
				case "integer":
					if (not reFind("^-?\d+$", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be an integer" });
					}
					break;
				case "numeric":
					if (not reFind("^-?\d+(\.\d+)?$", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be a number" });
					}
					break;
				case "url":
					if (not isValid("url", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be a valid URL" });
					}
					break;
				case "uuid":
					if (not isValid("uuid", parameters[parameter.name])) {
						arrayAppend(errors, { "code"="202", "field"=parameter.name, "inp"=parameter["in"], "detail"="must be a valid UUID" });
					}
					break;
				}
			}
		}

		arguments.req.parameters = parameters;

		return errors;
	}

	public array function addAuthentication(required struct req, required struct res) {
		var allowedAuth = listToArray(application.fapi.getConfig("api", "authentication"));
		var thisauth = "";
		var result = [];

		if (arguments.req.method eq "OPTIONS") {
			arguments.req.authentication = "";
			return [];
		}

		for (thisauth in allowedAuth) {
			result = invoke(this, "addAuthentication#thisauth#", { req=arguments.req });

			if (arrayLen(result)) {
				// this auth method matched, but returned an error
				arguments.req.authentication = thisauth;
				return result;
			}
			else if (structKeyExists(arguments.req, "user")) {
				arguments.req.authentication = thisauth;
				return result;
			}
		}

		arguments.req.authentication = "";
		return [];
	}

	public array function addAuthenticationPublic(required struct req) {
		arguments.req.user = {
			"authentication" = "public"
		};

		return [];
	}

	public array function addAuthenticationBasic(required struct req) {
		var auth = "";
		var stResult = {};
		var i = 0;

		if (structKeyExists(arguments.req.headers, "Authorization") and reFindNoCase("^Basic \w+$", arguments.req.headers.Authorization)) {
			auth = ToString(ToBinary(listLast(arguments.req.headers.Authorization, " ")));
			form.userlogin = listFirst(auth, ":");
			form.password = listRest(auth, ":");
			stResult = application.security.userdirectories.CLIENTUD.authenticate();

			if (stResult.authenticated) {
				arguments.req.user = {
					"id" = stResult.userid & "_CLIENTUD",
					"authentication" = "basic",
					"groups" = application.security.userdirectories.CLIENTUD.getUserGroups(stResult.userid)
				};

				for (i=1; i<=arrayLen(arguments.req.user.groups); i++) {
					arguments.req.user.groups[i] = arguments.req.user.groups[i] & "_CLIENTUD";
				}

				arguments.req.user.roles = application.security.factory.role.groupsToRoles(arrayToList(arguments.req.user.groups));

				return [];
			}
			else {
				return [{ "code"="101", "detail"=stResult.message }];
			}
		}

		return [];
	}

	public array function addAuthenticationKey(required struct req) {
		var stKey = {};

		if (structKeyExists(arguments.req.headers, "Authorization") and reFindNoCase("^\w+$", arguments.req.headers.Authorization)) {
			stKey = this.oAccessKey.getByKey(key=arguments.req.headers.Authorization);

			if (structIsEmpty(stKey)) {
				return [{ "code"="101", "detail"="Unknown API key" }];
			}

			arguments.req.user = {
				"id" = stKey.accessKeyID,
				"authentication" = "key",
				"authorisation" = deserializeJSON(stKey.authorisation)
			};
		}

		return [];
	}

	public array function addAuthenticationStatelessKey(required struct req) {
		var stKey = {};

		if (structKeyExists(arguments.req.headers, "Authorization") and reFindNoCase("^\w{8}-\w{4}-\w{4}-\w{16}:\w+:\w+$", arguments.req.headers.Authorization)) {
			var stProfile = application.fapi.getContentObject(typename="dmProfile", objectid=listFirst(arguments.req.headers.Authorization, ":"));

			// Validate the key signature
			var stringToSign = listDeleteAt(arguments.req.headers.Authorization, 3, ":");
			var secret = application.fapi.getConfig("api", "secret");
			var encryptedSignature = lcase(binaryEncode(application.fc.lib.cdn.cdns.s3.HMAC_SHA256(stringToSign, secret.getBytes("UTF8")), 'hex'));
			if (encryptedSignature neq listLast(arguments.req.headers.Authorization, ":")) {
				return [{ "code"="101", "detail"="Invalid API key", "debug"={"string_to_sign"=stringToSign} }];
			}

			// No matching user
			if (structKeyExists(stProfile, "bDefaultObject")) {
				return [{ "code"="101", "detail"="Unknown user" }];
			}

			// Key has expired
			var expiry = listGetAt(arguments.req.headers.Authorization, 2, ":");
			var curtime = round(getTickCount() / 1000);
			if (not isNumeric(expiry) or expiry < curtime) {
				return [{ "code"="101", "detail"="Expired API key", "debug"={"current_time"=curtime} }];
			}

			arguments.req.user = {
				"id" = stProfile.username,
				"profile" = stProfile,
				"authentication" = "statelesskey",
				"groups" = application.security.userdirectories[listLast(stProfile.userdirectory)].getUserGroups(listDeleteAt(stProfile.username, listLen(stProfile.username, "_"), "_"))
			};
			arguments.req.user.roles = application.security.factory.role.groupsToRoles(arrayToList(arguments.req.user.groups));
		}

		return [];
	}

	public array function addAuthenticationSession(required struct req) {
		var stKey = {};

		if (application.security.isLoggedIn()) {
			arguments.req.user = {
				"id" = application.security.getCurrentUserID(),
				"profile" = session.dmProfile,
				"authentication" = "session",
				"roles" = application.security.getCurrentRoles()
			};
		}

		return [];
	}

	public array function addAuthorization(required struct req) {
		// ignore authentication for OPTIONS requests
		if (arguments.req.method eq "OPTIONS") {
			arguments.req.authorized = true;
			return [];
		}

		// no login is required for this endpoint
		if (arguments.req.handler.permission eq "public") {
			arguments.req.authorized = true;
			return [];
		}

		// if no authentication matched, the default is false
		if (arguments.req.authentication eq "") {
			arguments.req.authorized = false;
			return [{ "code"="101", "detail"="No authentication matched" }];
		}

		// no login is required for anything
		if (arguments.req.authentication eq "public") {
			arguments.req.authorized = true;
			return [];
		}

		// throw error if no user was authenticated
		if (not structKeyExists(arguments.req, "user")) {
			return [{ "code"="105", "message"="Anonymous users are not authenticated for this request" }];
		}

		// any authentication access is allowed
		if (arguments.req.handler.permission eq "authenticated") {
			arguments.req.authorized = true;
			return [];
		}

		// permission is based on a parameter in the endpoint
		else if (left(arguments.req.handler.permission, 10) eq "{typename}") {
			arguments.req.authorized = checkPermission(req=arguments.req, permission=listLast(arguments.req.handler.permission, ":"), typename=arguments.req.parameters.typename);
		}
		else if (find(":", arguments.req.handler.permission)) {
			arguments.req.authorized = checkPermission(req=arguments.req, permission=listLast(arguments.req.handler.permission, ":"), typename=listFirst(arguments.req.handler.permission, ":"));
		}
		else {
			arguments.req.authorized = checkPermission(req=arguments.req, permission=arguments.req.handler.permission);
		}

		if (not arguments.req.authorized) {
			return [{ "code"="105" }];
		}

		return [];
	}

	public array function addPreprocessedParameters(required struct req, required struct res) {
		if (arrayLen(arguments.req.handler.preprocessing) eq 0 or arguments.req.method eq "OPTIONS") {
			return [];
		}

		var preprocesser = {};
		var stArgs = {};

		for (preprocessor in arguments.req.handler.preprocessing) {
			stArgs = duplicate(preprocessor.args);
			structAppend(stArgs, arguments);
			structAppend(stArgs, arguments.req.parameters);
			arguments.req.parameters[preprocessor.name] = invoke(this.apis[arguments.req.handler.api], preprocessor.method, stArgs);

			if (errorCount(arguments.req, arguments.res)) {
				return [];
			}
		}

		return [];
	}

	public array function executeEndpointFunction(required struct req, required struct res) {
		if (arguments.req.method neq "OPTIONS") {
			invoke(this.apis[request.req.handler.api], arguments.req.handler.function, arguments.req.parameters);
		}
		else {
			structDelete(arguments.res, "content");
		}

		return [];
	}

	public boolean function checkPermission(required struct req, required string permission, string typename="") {
		if (find(":", arguments.permission)) {
			arguments.typename = listFirst(arguments.permission, ":");
			arguments.permission = listLast(arguments.permission, ":");
		}

		if (arguments.permission eq "authenticated") {
			return listFindNoCase("public,key,statelesskey,basic,session", arguments.req.authentication) gt 0;
		}

		switch (arguments.req.authentication) {
			case "public":
				return true;
			case "key":
				return structKeyExists(arguments.req.user.authorisation, arguments.typename)
					and structKeyExists(arguments.req.user.authorisation[arguments.typename], arguments.permission)
					and arguments.req.user.authorisation[arguments.typename][arguments.permission];
			case "statelesskey":
				switch (arguments.permission) {
					case "list": return application.security.checkPermission(role=arguments.req.user.roles, permission="view", type=arguments.typename);
					case "get": return application.security.checkPermission(role=arguments.req.user.roles, permission="view", type=arguments.typename);
					case "create": return application.security.checkPermission(role=arguments.req.user.roles, permission="create", type=arguments.typename);
					case "update": return application.security.checkPermission(role=arguments.req.user.roles, permission="edit", type=arguments.typename);
					case "delete": return application.security.checkPermission(role=arguments.req.user.roles, permission="delete", type=arguments.typename);
					default: return application.security.checkPermission(role=arguments.req.user.roles, permission=arguments.permission, type=arguments.typename);
				}
			case "basic":
				switch (arguments.permission) {
					case "list": return application.security.checkPermission(role=arguments.req.user.roles, permission="view", type=arguments.typename);
					case "get": return application.security.checkPermission(role=arguments.req.user.roles, permission="view", type=arguments.typename);
					case "create": return application.security.checkPermission(role=arguments.req.user.roles, permission="create", type=arguments.typename);
					case "update": return application.security.checkPermission(role=arguments.req.user.roles, permission="edit", type=arguments.typename);
					case "delete": return application.security.checkPermission(role=arguments.req.user.roles, permission="delete", type=arguments.typename);
					default: return application.security.checkPermission(role=arguments.req.user.roles, permission=arguments.permission, type=arguments.typename);
				}
			case "session":
				switch (arguments.permission) {
					case "list": return application.security.checkPermission(permission="view", type=arguments.typename);
					case "get": return application.security.checkPermission(permission="view", type=arguments.typename);
					case "create": return application.security.checkPermission(permission="create", type=arguments.typename);
					case "update": return application.security.checkPermission(permission="edit", type=arguments.typename);
					case "delete": return application.security.checkPermission(permission="delete", type=arguments.typename);
					default: return application.security.checkPermission(permission=arguments.permission, type=arguments.typename);
				}
		}

		return false;
	}

	// return result, based on Accept-Encoding header
	public void function sendResponse(required struct req, required struct res){
		var key = "";

		// default response type
		if (not structKeyExists(arguments.res, "type")) {
			arguments.res.type = "json";
		}

		// process content
		if (arrayLen(arguments.res.errors)) {
			arguments.res.content["errors"] = arguments.res.errors;
		}
		else if (not structkeyexists(arguments.res, "content") or (isStruct(arguments.res.content) and structIsEmpty(arguments.res.content))) {
			arguments.res["content"] = "";
		}
		else {
			switch (arguments.res.type) {
				case "json": arguments.res["content"] = serializeJSON(arguments.res.content); break;
				case "html": savecontent variable="arguments.res.content" { dump(var=arguments.res.content); }; break;
			}
		}

		// content id headers
		arguments.res.headers["Content-MD5"] = hash(arguments.res.content);
		arguments.res.headers["ETag"] = hash(arguments.res.content);

		if (arguments.req.clearResponse) {
			structDelete(arguments.res, "content");
		}

		if (structKeyExists(arguments.res, "headers")){
			for (key in arguments.res.headers){
				cfheader(name="#key#", value=arguments.res.headers[key]);
			}

			cfheader(name="processing_time", value=getTickCount() - arguments.res.start);
		}

		if (structKeyExists(arguments.res, "content")) {
			application.fapi.stream(argumentCollection=res);
		}
		else {
			cfcontent(reset=true);
			abort;
		}
	}


	// construct error response
	public void function addError(required struct req, required struct res, required string code, string message, string detail, string field, string inp, any debug, boolean clearContent=true){
		var err = {
			"code" = numberformat(arguments.code, "000")
		};
		var errors = isDefined("arguments.res.content.errors") ? arguments.res.content.errors : [];

		// use default message if necessary
		if (structKeyExists(arguments, "message")) {
			err["message"] = arguments.message;
		}
		else {
			err["message"] = this.codes[err.code].message;
		}

		if (structKeyExists(arguments, "detail")) {
			err["detail"] = arguments.detail;
		}
		if (structKeyExists(arguments, "field")) {
			err["field"] = arguments.field;
		}
		if (structKeyExists(arguments, "inp")) {
			err["in"] = arguments.inp;
		}

		// fill out response with missing values
		arguments.res["status"] = this.codes[err.code].status;

		if (arguments.clearContent) {
			this.clearResponse(res=arguments.res);
		}

		if (request.mode.debug or isDefined("arguments.req.query_params.debug")) {
			addResponse(res=arguments.res, key="x-request", data={
				"method" = arguments.req.method,
				"url" = arguments.req.url,
				"query_params" = arguments.req.query_params,
				"form" = arguments.req.form,
				"cgi_query_string" = cgi.query_string,
				"headers" = arguments.req.headers,
				"content" = arguments.req.content,
				"parameters" = structKeyExists(arguments.req, "parameters") ? arguments.req.parameters : {},
				"handler" = structKeyExists(arguments.req, "handler") ? arguments.req.handler : {}
			});
			if (structKeyExists(arguments, "debug")) {
				addResponse(res=arguments.res, key="x-debug", data=arguments.debug);
			}
		}

		arrayappend(errors, err);
		addResponse(res=arguments.res, key="errors", data=errors);
	}

	public numeric function errorCount(required struct req, required struct res) {
		if (isDefined("arguments.res.content.errors")) {
			return arrayLen(arguments.res.content.errors);
		}
		else {
			return 0;
		}
	}

	public void function setResponse(required struct res, required any data) {
		arguments.res.content = duplicate(arguments.data);
	}

	public void function addResponse(required struct res, required string key, required any data) {
		arguments.res.content[arguments.key] = duplicate(arguments.data);
	}

	public void function clearResponse(required struct res) {
		arguments.res.content = {};
	}

	public query function getErrorCodes() {
		var q = queryNew("type,typeHint,code,message,status");
		var type = {};
		var code = "";

		for (type in this.codeTypeHints) {
			for (code in type.codes) {
				queryAddRow(q);
				querySetCell(q, "type", type.title);
				querySetCell(q, "typeHint", type.hint);
				querySetCell(q, "code", code);
				querySetCell(q, "message", structKeyExists(this.codes[code], "message") ? this.codes[code].message : "");
				querySetCell(q, "status", this.codes[code].status);
			}
		}

		return q;
	}

	public string function dateToRFC(required any input, boolean includeTime=true) {
		var utcDate = "";

		if (not isDate(arguments.input)) {
			return "";
		}

		utcDate = DateConvert("Local2UTC", arguments.input);

		if (arguments.includeTime) {
			return dateFormat(utcDate, "YYYY-mm-dd") & "T" & timeFormat(utcDate, "HH:mm:ss") & "Z";
		}
		else {
			return dateFormat(utcDate, "YYYY-mm-dd");
		}
	}

	public date function rfcToDate(required any input, boolean includeTime=true) {
		var sdf = "";
		var pos = "";

		if (arguments.includeTime) {
			if (reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$", arguments.input)) {
				sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
			}
			else {
				sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss'Z'");
			}
		}
		else {
			sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd");
		}
		pos = CreateObject("java", "java.text.ParsePosition").init(0);

		return sdf.parse(arguments.input, pos);
	}

	public string function validateDate(required any input, boolean includeTime=true) {
		if (arguments.includeTime) {
			if (not reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$", arguments.input)) {
				return "Date/times must be in the form yyyy-MM-ddTHH:mm:ssZ";
			}
		}
		else {
			if (not reFind("^\d{4}-\d{2}-\d{2}$", arguments.input)) {
				return "Dates must be in the form yyyy-MM-dd";
			}
		}

		return "";
	}

}