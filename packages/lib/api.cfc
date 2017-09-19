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
	this.requestProcessors = ["addCORS","addHandler","addResponseType","addContent","addParameters","addAuthentication","addAuthorization"];

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
		var apis = utils.getComponents("api");
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
					"attrs" = duplicate(func)
				};

				if (structKeyExists(func, "parameters") and arrayLen(func.parameters)) {
					for (i in func.parameters) {
						arrayAppend(stHandler.parameters, application.fc.lib.swagger.getSwaggerParameter(i));
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

	// parse every request into a self contained data packet
	public void function handleRequest(){
		var processor = "";
		var error_code = "";
		var error_codes = [];
		var processorFunc = "";
		
		if (structIsEmpty(this.apis)) {
			initializeAPIs();
		}

		request.res = createResponse();
		request.req = createRequest();

		try {
			// each addXxx function checks the request to add information to the req 
			// object if it is valid and return errors if it is not
			for (processor in this.requestProcessors) {
				processorFunc = this[processor];
				error_codes = processorFunc(req=request.req, res=request.res);
				if (arrayLen(error_codes)) { // handles 201 and 202 error cases
					for (error_code in error_codes) {
						addError(req=request.req, res=request.res, argumentCollection=error_code);
					}
					sendResponse(res=request.res);
					return;
				}
			}

			invoke(this.apis[request.req.handler.api], request.req.handler.function, request.req.parameters); 
		} catch (any e) {
			application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
			addError(req=request.req, res=request.res, code="999", message=e.message, debug=application.fc.lib.error.normalizeError(e));
		}

		sendResponse(res=request.res);
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
		var req = {};
		req["accept"] = "";
		req["method"] = requestData.method;
		req["url"] = "";
		req["query_params"] = {};
		req["query_string"] = "";
		req["headers"] = duplicate(requestData.headers);
		req["content_string"] = requestData.content;
		req["content"] = {};
		req["form"] = duplicate(form);
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

	public array function addCORS(required struct req, required struct res) {
		var regex = "";

		if (arrayLen(this.originWhitelist) and this.originWhitelist[1] eq "*" and structKeyExists(arguments.req.headers, "Origin")) {
			arguments.res.headers["Access-Control-Allow-Origin"] = arguments.req.headers.Origin;
			return [];
		}
		else if (arrayLen(this.originWhitelist) and this.originWhitelist[1] eq "*") {
			arguments.res.headers["Access-Control-Allow-Origin"] = "*";
			return [];
		}
		else if (structKeyExists(arguments.req.headers, "Origin")) {
			for (regex in this.originWhitelistRegex) {
				if (regex.matcher(arguments.req.headers.Origin).matches()) {
					arguments.res.headers["Access-Control-Allow-Origin"] = arguments.req.headers.Origin;
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
				arrayAppend(allowed_methods, ucase(handler.method));
			}
		}

		if (structKeyExists(arguments.req, "handler")) {
			arguments.res.headers["Allow"] = arrayToList(allowed_methods, ", ");
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
		if (structkeyexists(arguments.req.headers, "accept")){
			for (i=1; i<=listlen(arguments.req.headers.accept, ";"); i++){
				switch (listgetat(arguments.req.headers.accept, i, ";")){
					case "text/html":
						arguments.res["type"] = "html";
						break;
					case "json": case "text/json": case "application/json":
						arguments.res["type"] = "json";
						break;
				}
			}
			if (not structkeyexists(arguments.res, "type")){
				return [{"code"="003"}];
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
		var err = {};

		for (parameter in arguments.req.handler.parameters) {
			switch (parameter.input) {
			case "path":
				parameters[parameter.name] = path_parts[arguments.req.handler.parts[parameter.name]];
				break;
			case "query":
				if (structKeyExists(arguments.req.query_params, parameter.name)) {
					parameters[parameter.name] = arguments.req.query_params[parameter.name];
				}
				else if (parameter.required) {
					err = { code="201", field=parameter.name, input=parameter.input };
					arrayAppend(errors, err);
				}
				break;
			case "header":
				if (structKeyExists(arguments.req.headers, parameter.name)) {
					parameters[parameter.name] = arguments.req.headers[parameter.name];
				}
				else if (parameter.required) {
					arrayAppend(errors, { code="201", field=parameter.name, input=parameter.input });
				}
				break;
			case "body":
				parameters[parameter.name] = arguments.req.content;
				break;
			case "form":
				if (structKeyExists(arguments.req.form, parameter.name)) {
					parameters[parameter.name] = arguments.req.form[parameter.name];
				}
				else if (parameter.required) {
					arrayAppend(errors, { code="201", field=parameter.name, input=parameter.input });
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
							arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="value at index #i-1# must be a valid UUID" });
						}
					}
					break;
				case "boolean":
					if (not isValid("boolean", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be boolean" });
					};
					break;
				case "datetime":
					if (not reFind("^\d{4}-\d{2}-\d{2}$", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be an RFC339 full-date string in the format YYYY-mm-dd" });
					}
					break;
				case "date":
					if (not reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be an RFC339 date-time string date in the format YYYY-mm-ddTHH:mm:ssZ" });
					}
					break;
				case "email":
					if (not isValid("email", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be a valid email address" });
					}
					break;
				case "integer":
					if (not reFind("^-?\d+$", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be an integer" });
					}
					break;
				case "numeric":
					if (not reFind("^-?\d+(\.\d+)?$", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be a number" });
					}
					break;
				case "url":
					if (not isValid("url", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be a valid URL" });
					}
					break;
				case "uuid":
					if (not isValid("uuid", parameters[parameter.name])) {
						arrayAppend(errors, { code="202", field=parameter.name, input=parameter.input, detail="must be a valid UUID" });
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

	public array function addAuthenticationPublish(required struct req) {
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

	public array function addAuthenticationSession(required struct req) {
		var stKey = {};

		if (application.security.isLoggedIn()) {
			arguments.req.user = {
				"id" = application.security.getCurrentUserID(),
				"authentication" = "session"
			};
		}

		return [];
	}

	public array function addAuthorization(required struct req) {
		// no login is required for this endpoint
		if (arguments.req.handler.permission eq "public") {
			arguments.req.authorized = true;
			return [];
		}

		// if no authentication matched, the default is false
		if (arguments.req.authentication eq "") {
			arguments.req.authorized = false;
		}

		// no login is required for anything
		if (arguments.req.authentication eq "public") {
			arguments.req.authorized = true;
			return [{ "code"="105" }];
		}

		// throw error if no user was authenticated
		if (not structKeyExists(arguments.req, "user")) {
			return [{ "code"="105", "message"="Anonymous users are not authenticated for this request" }];
		}

		// permission is based on a parameter in the endpoint
		if (left(arguments.req.handler.permission, 10) eq "{typename}") {
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

	public boolean function checkPermission(required struct req, required string permission, string typename="") {
		if (find(":", arguments.permission)) {
			arguments.typename = listFirst(arguments.permission, ":");
			arguments.permission = listLast(arguments.permission, ":");
		}

		switch (arguments.req.authentication) {
			case "public":
				return true;
			case "key":
				return structKeyExists(arguments.req.user.authorisation, arguments.typename) and structKeyExists(arguments.req.user.authorisation[arguments.typename], arguments.permission) and arguments.req.user.authorisation[arguments.typename][arguments.permission];
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
	public void function sendResponse(required struct res){
		var key = "";

		if (structKeyExists(arguments.res, "headers")){
			for (key in arguments.res.headers){
				cfheader(name="#key#", value="#arguments.res.headers[key]#");
			}

			cfheader(name="processing_time", value="#getTickCount() - arguments.res.start#");
		}

		if (arrayLen(arguments.res.errors)) {
			arguments.res.content["errors"] = arguments.res.errors;
		}
		else if (not structkeyexists(arguments.res, "content") or structIsEmpty(arguments.res.content)) {
			arguments.res["content"] = "";
		}

		if (not structKeyExists(arguments.res, "type")) {
			arguments.res.type = "json";
		}

		if (arguments.res.type eq "html" and not isSimpleValue(arguments.res.content)){
			savecontent variable="arguments.res.content" {
				dump(arguments.res.content);
			}
		}

		application.fapi.stream(argumentCollection=res);
	}


	// construct error response
	public void function addError(required struct req, required struct res, required string code, string message, string detail, string field, string input, any debug, boolean clearContent=true){
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

		// fill out response with missing values
		arguments.res["status"] = this.codes[err.code].status;

		if (arguments.clearContent) {
			this.clearResponse(res=arguments.res);
		}

		if (request.mode.debug) {
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

	public void function setResponse(required struct res, required struct data) {
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

}