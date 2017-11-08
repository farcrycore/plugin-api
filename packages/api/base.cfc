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
		var stSwagger = duplicate(application.fc.lib.api.swagger[request.req.handler.api]);
		var path = "";
		var method = "";

		for (path in stSwagger.paths) {
			for (method in stSwagger.paths[path]) {
				if (request.req.authentication eq "public") {
					structDelete(stSwagger.paths[path][method], "x-permission");
				}
				else if (stSwagger.paths[path][method]["x-permission"] eq "public") {
					structDelete(stSwagger.paths[path][method], "x-permission");
				}
				else if (not structKeyExists(request.req, "user")) {
					structDelete(stSwagger.paths[path], method);
				}
				else if (not application.fc.lib.api.checkPermission(req=request.req, permission=stSwagger.paths[path][method]["x-permission"])) {
					structDelete(stSwagger.paths[path], method);
				}
				else {
					structDelete(stSwagger.paths[path][method], "x-permission");
				}
			}
		}

		setResponse(stSwagger);
	}


	// utility functions
	public void function addError(){
		application.fc.lib.api.addError(req=request.req, res=request.res, argumentCollection=arguments);
	}

	public numeric function errorCount() {
		return application.fc.lib.api.errorCount(req=request.req, res=request.res);
	}

	public void function setResponse(required any data) {
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
		var swaggerDef = {};
		var key = "";
		var stResult = {};
		var stItem = {};

		if (not structKeyExists(arguments, "stObject")) {
			o = application.fapi.getContentType(typename=arguments.typename);
		}
		else {
			arguments.typename = arguments.stObject.typename;
			o = application.fapi.getContentType(typename=arguments.stObject.typename);
		}

		// if the type has a custom api handler ...
		if (structKeyExists(o, "getAPIResponse")) {
			return o.getAPIResponse(argumentCollection=arguments);
		}

		if (not structKeyExists(arguments, "stObject")) {
			arguments.stObject = o.getData(typename=arguments.typename, objectid=arguments.objectid, bArraysAsStructs=true);
		}

		// otherwise, use the swagger definition to clean up the response
		swaggerDef = application.fc.lib.api.swagger[request.req.handler.api].definitions[arguments.stObject.typename].properties;
		stResult = {
			"objectid" = arguments.stObject.objectid,
			"typename" = arguments.stObject.typename
		};

		for (key in swaggerDef) {
			if (structKeyExists(arguments.stObject, key)) {
				if (structKeyExists(o, "getAPI#key#")) {
					stResult[key] = invoke(o, "getAPI#key#", { stObject=arguments.stObject });
					continue;
				}

				if (structKeyExists(swaggerDef[key], "$ref") and swaggerDef[key]["$ref"] eq "##/definitions/ItemReference") {
					if (not len(arguments.stObject[key])) {
						stResult[key] = {};
					}
					else {
						stResult[key] = { "objectid"=arguments.stObject[key] };
						if (listLen(application.fapi.getPropertyMetadata(typename=arguments.stObject.typename, property=key, md="ftJoin", default="")) eq 1) {
							stResult[key]["typename"] = application.fapi.getPropertyMetadata(typename=arguments.stObject.typename, property=key, md="ftJoin");
						}
						else {
							stResult[key]["typename"] = application.fapi.findType(objectid=arguments.stObject[key]);
						}
					}

					continue;
				}

				switch (swaggerDef[key].type) {
				case "array":
					stResult[key] = [];

					if (isArray(arguments.stObject[key])) {
						for (stItem in arguments.stObject[key]) {
							if (isStruct(stItem)) {
								arrayAppend(stResult[key], {
									"typename" = stItem.typename,
									"objectid" = stItem.data
								});
							}
							else if (isValid("uuid", stItem)) {
								arrayAppend(stResult[key], {
									"typename" = application.fapi.findType(stItem),
									"objectid" = stItem
								});
							}
							else {
								arrayAppend(stResult[key], stItem);
							}
						}
					}
					else {
						for (stItem in listToArray(arguments.stObject[key])) {
							if (isValid("uuid", stItem)) {
								arrayAppend(stResult[key], {
									"typename" = application.fapi.findType(stItem),
									"objectid" = stItem
								});
							}
							else {
								arrayAppend(stResult[key], stItem);
							}
						}
					}
					break;
				case "boolean":
					if (len(arguments.stObject[key]) and arguments.stObject[key]) {
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

	public void function updateObject(required struct stObject, required struct stUpdate) {
		var swaggerDef = application.fc.lib.api.swagger[request.req.handler.api].definitions[arguments.stObject.typename & "Update"].schema.properties;
		var key = "";
		var stItem = {};
		var o = application.fapi.getContentType(typename=arguments.stObject.typename);

		if (structKeyExists(o, "updateFromAPIBody")) {
			invoke(o, "updateFromAPIBody", { stObject=arguments.stObject, stUpdate=arguments.stUpdate });
			return;
		}

		for (key in swaggerDef) {
			if (structKeyExists(o, "getValueFromAPI#key#")) {
				arguments.stObject[key] = invoke(o, "getValueFromAPI#key#", { stObject=arguments.stObject, stUpdate=arguments.stUpdate });
				continue;
			}

			if (structKeyExists(arguments.stUpdate, key)) {
				if (structKeyExists(swaggerDef[key], "$ref") and swaggerDef[key]["$ref"] eq "##/definitions/ItemReference") {
					if (not len(arguments.stUpdate[key])) {
						arguments.stObject[key] = "";
					}
					else {
						arguments.stObject[key] = arguments.stUpdate[key].objectid;
					}

					continue;
				}

				switch (swaggerDef[key].type) {
				case "array":
					switch (application.fapi.getPropertyMetadata(typename=arguments.stObject.typename, property=key, md="ftType", default="string")) {
						case "list":
							arguments.stObject[key] = "";
							for (stItem in arguments.stUpdate[key]) {
								arguments.stObject[key] = listAppend(arguments.stObject[key], stItem);
							}
							break;
						case "array":
							arguments.stObject[key] = [];
							for (stItem in arguments.stUpdate[key]) {
								arrayAppend(arguments.stObject[key], stItem.objectid);
							}
							break;
					}
					break;
				case "string":
					if (structKeyExists(swaggerDef[key], "format")) {
						switch (swaggerDef[key].format) {
						case "date":
							if (len(arguments.stUpdate[key])) {
								arguments.stObject[key] = rfcToDate(input=arguments.stUpdate[key], includeTime=false);
							}
							else {
								arguments.stObject[key] = "";
							}
							break;
						case "date-time":
							if (len(arguments.stUpdate[key])) {
								arguments.stObject[key] = rfcToDate(input=arguments.stUpdate[key], includeTime=true);
							}
							else {
								arguments.stObject[key] = "";
							}
							break;
						default:
							arguments.stObject[key] = arguments.stUpdate[key];
						}
					}
					else {
						arguments.stObject[key] = arguments.stUpdate[key];
					}
					break;
				default:
					arguments.stObject[key] = arguments.stUpdate[key];
				}
			}
		}
	}

	private function dateToRFC(required any input, boolean includeTime=true) {
		return application.fc.lib.api.dateToRFC(argumentCollection=arguments);
	}

	private function rfcToDate(required any input, boolean includeTime=true) {
		return application.fc.lib.api.rfcToDate(argumentCollection=arguments);
	}

}