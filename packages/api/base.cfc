component {

	/**
	* @handle GET 
	* @tags General
	* @security none
	* @200 #/definitions/Status:API Status
	* @default #/definitions/FailedRequest:Failure
	* @permission public
	*/
	public void function status(){
		addResponse("version", "1.0.0");
	}

	/**
	* @handle GET /swagger
	* @document false
	* @security none
	* @permission public
	*/
	public void function getSwagger() {
		setResponse(application.fc.lib.api.swagger[request.req.handler.api]);
	}


	// utility functions
	public void function addError(){
		application.fc.lib.api.addError(req=request.req, res=request.res, argumentCollection=arguments);
	}

	public void function setResponse(required struct data) {
		application.fc.lib.api.setResponse(res=request.res, res=request.res, argumentCollection=arguments);
	}

	public void function addResponse(required string key, required any data) {
		application.fc.lib.api.addResponse(res=request.res, res=request.res, argumentCollection=arguments);
	}

	public void function clearResponse() {
		application.fc.lib.api.clearResponse(res=request.res, res=request.res, argumentCollection=arguments);
	}

	public struct function getResponseObject(struct stObject, string typename, uuid objectid) {
		var o = {};
		var stObject = {};
		var swaggerDef = {};
		var key = "";
		var stResult = {};
		var typename = structKeyExists(arguments, "stObject") ? arguments.stObject.typename : arguments.typename;

		if (not structKeyExists(arguments, "stObject")) {
			o = application.fapi.getContentType(typename=arguments.typename);
		}
		else {
			o = application.fapi.getContentType(typename=arguments.stObject.typename);
		}

		// if the type has a custom api handler ...
		if (structKeyExists(o, "getAPIResponse")) {
			return o.getAPIResponse(argumentCollection=arguments);
		}

		if (not structKeyExists(arguments, "stObject")) {
			arguments.stObject = o.getData(typename=arguments.typename, objectid=arguments.objectid);
		}

		// otherwise, use the swagger definition to clean up the response
		swaggerDef = application.fc.lib.api.swagger[request.req.handler.api].definitions[arguments.stObject.typename].allOf[2].properties;
		stResult = {
			"objectid" = arguments.stObject.objectid,
			"typename" = arguments.stObject.typename
		};

		for (key in swaggerDef) {
			if (structKeyExists(arguments.stObject, key)) {
				switch (swaggerDef[key].type) {
				case "array":
					stResult[key] = arguments.stObject[key];
					break;
				case "boolean":
					if (arguments.stObject[key]) {
						stResult[key] = true;
					}
					else {
						stResult[key] = false;
					}
					break;
				case "string":
					if (structKeyExists(swaggerDef[key], "format")) {
						switch (swaggerDef[key].format) {
						case "date":
							if (application.fapi.showFarcryDate(arguments.stObject[key])) {
								stResult[key] = dateToRFC(input=arguments.stObject[key], includeTime=false);
							}
							else {
								stResult[key] = "";
							}
							break;
						case "date-time":
							if (application.fapi.showFarcryDate(arguments.stObject[key])) {
								stResult[key] = dateToRFC(input=arguments.stObject[key], includeTime=true);
							}
							else {
								stResult[key] = "";
							}
							break;
						default:
							stResult[key] = arguments.stObject[key];
						}
					}
					else {
						stResult[key] = arguments.stObject[key];
					}
					break;
				case "integer":
					stResult[key] = isNumeric(arguments.stObject[key]) ? int(arguments.stObject[key]) : 0;
					break;
				case "float":
					stResult[key] = isNumeric(arguments.stObject[key]) ? arguments.stObject[key] : 0;
					break;
				default:
					stResult[key] = arguments.stObject[key];
				}
			}
		}

		return stResult;
	}

	private function dateToRFC(required any input, boolean includeTime=true) {
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

}