component {

	public struct function getSwaggerAPI(required struct metadata, required string prefix, required array typenames, struct stSwagger) {
		var swaggerBase = structKeyExists(application, "swaggerBase") ? application.swaggerBase : "/farcry/plugins/api/config/swagger.json";
		var methodIn = {};
		var method = "";
		var handle = "";
		var path = "";
		var typename = "";

		if (not structKeyExists(arguments, "stSwagger")) {
			arguments.stSwagger = deserializeJSON(fileRead(swaggerBase));
			arguments.stSwagger.info.title = application.fapi.getConfig("general", "sitetitle", "") & (structKeyExists(arguments.metadata, "title") ? ": " & arguments.metadata.title : "");
			arguments.stSwagger.info.description = structKeyExists(arguments.metadata, "description") ? arguments.metadata.description : "";
			arguments.stSwagger.info.version = listLast(arguments.metadata.fullname, ".");
			//arguments.stSwagger.host = application.fc.lib.seo.getCanonicalDomain(bUseHostname=true);
			arguments.stSwagger.schemes = listToArray(application.fapi.getConfig("api", "schemes", "http"));
			//arguments.stSwagger.basePath = "";
			arguments.stSwagger.produces = ["text/json","text/html"];
			arguments.stSwagger.paths = {};
			arguments.stSwagger.definitions["ContentType"] = {
				"type" : "object",
				"discriminator" : "typename",
				"properties" : {
					"objectid" : {
						"type" : "string",
						"format" : "uuid"
					},
					"typename" : {
						"type" : "string",
						"enum" : arguments.typenames
					}
				},
				"required" : [
					"objectid",
					"typename"
				]
			};
		}

		if (not structKeyExists(arguments.metadata, "functions")) {
			return arguments.stSwagger;
		}

		switch (application.fapi.getConfig("api", "authentication", "public")) {
			case "public":
				// no security
				break;
			case "basic":
				stSwagger["security"] = {
					"basic" = []
				};
				stSwagger["securityDefinitions"] = {
					"basic" = {
						"type" = "basic"
					}
				};
				break;
			case "key":
				stSwagger["security"] = {
					"api_key" = []
				};
				stSwagger["securityDefinitions"] = {
					"api_key" = {
						"type" = "apiKey",
						"name" = "Authorization",
						"in" = "header"
					}
				};
				break;
			default:
				stSwagger["security"] = {};
				stSwagger["security"][application.fapi.getConfig("api", "authentication", "public")] = [];
				stSwagger["securityDefinitions"] = {
					"api_key" = {
						"type" = "apiKey",
						"name" = "Authorization",
						"in" = "header",
						"x-custom-auth" = application.fapi.getConfig("api", "authentication", "public")
					}
				};
				break;
		}

		for (typename in arguments.typenames) {
			arguments.stSwagger.definitions[typename] = getSwaggerDefinition(typename=typename);
		}

		for (methodIn in arguments.metadata.functions) {
			if (structKeyExists(methodIn, "handle") and (not structKeyExists(methodIn, "document") or methodIn.document eq true)) {
				handle = listToArray(trim(methodIn.handle), " ");
				if (arrayLen(handle) eq 2) {
					handle[2] = arguments.prefix & handle[2];
				}
				else {
					handle[2] = arguments.prefix;
				}
				method = lcase(handle[1]);
				path = handle[2];

				if (not structKeyExists(arguments.stSwagger.paths, path)) {
					arguments.stSwagger.paths[path] = {};
				}

				arguments.stSwagger.paths[path][method] = getSwaggerMethod(metadata=methodIn, typenames=arguments.typenames);

				if (isSimpleValue(arguments.stSwagger.paths[path][method].responses["200"])) {
					if (reFind("^\w+(:.*)$", arguments.stSwagger.paths[path][method].responses["200"])) {
						typename = arguments.stSwagger.paths[path][method].responses["200"];

						if (not structKeyExists(arguments.stSwagger.definitions, typename)) {
							arguments.stSwagger.definitions[typename] = getSwaggerDefinition(typename=typename);
						}

						arguments.stSwagger.paths[path][method].responses["200"] = {
							"schema" = {
								"$ref": "##/definitions/#typename#"
							},
							"description" = ""
						};

						if (find(":", arguments.stSwagger.paths[path][method].responses["200"].schema["$ref"])) {
							methodOut.responses[attr]["description"] = listRest(arguments.stSwagger.paths[path][method].responses["200"].schema["$ref"], ":");
							methodOut.responses[attr].schema.items["$ref"] = listFirst(arguments.stSwagger.paths[path][method].responses["200"].schema["$ref"], ":");
						}
					}
					else if (reFind("^\[\]\w+$", arguments.stSwagger.paths[path][method].responses["200"])) {
						typename = mid(arguments.stSwagger.paths[path][method].responses["200"], 3, len(arguments.stSwagger.paths[path][method].responses["200"]));

						if (not structKeyExists(arguments.stSwagger.definitions, typename)) {
							arguments.stSwagger.definitions[typename] = getSwaggerDefinition(typename=typename);
						}

						arguments.stSwagger.paths[path][method].responses["200"] = {
							"schema" = {
								"type" = "array",
								"items" = {
									"$ref" = "##/definitions/#typename#"
								}
							}
						};

						if (find(":", arguments.stSwagger.paths[path][method].responses["200"].schema.items["$ref"])) {
							methodOut.responses[attr].description = listRest(arguments.stSwagger.paths[path][method].responses["200"].schema.items["$ref"], ":");
							methodOut.responses[attr].schema.items["$ref"] = listFirst(arguments.stSwagger.paths[path][method].responses["200"].schema.items["$ref"], ":");
						}
					}
				}
			}
		}

		if (structKeyExists(arguments.metadata, "extends")) {
			getSwaggerAPI(metadata=arguments.metadata.extends, argumentCollection=arguments);
		}

		return arguments.stSwagger;
	}

	public struct function getSwaggerMethod(required struct metadata, required array typenames) {
		var methodOut = {
			"parameters" = []
		};
		var paramIn = {};
		var attr = ""
		var definition = "";

		if (structKeyExists(arguments.metadata, "displayname")) {
			methodOut["summary"] = arguments.metadata.displayname;
		}

		if (structKeyExists(arguments.metadata, "hint")) {
			methodOut["description"] = arguments.metadata.hint;
		}

		if (structKeyExists(arguments.metadata, "tags")) {
			methodOut["tags"] = listToArray(arguments.metadata.tags);
		}

		if (structKeyExists(arguments.metadata, "parameters") and arrayLen(arguments.metadata.parameters)) {
			for (paramIn in arguments.metadata.parameters) {
				arrayAppend(methodOut.parameters, getSwaggerParameter(paramIn));
			}
		}

		methodOut["responses"] = {};
		for (attr in arguments.metadata) {
			if ((len(attr) eq 3 and isNumeric(attr)) or attr eq "default") {
				methodOut.responses[attr] = getSwaggerResponse(arguments.metadata[attr]);

				if (reFindNoCase("^(\[\])?##/definitions/ContentType", arguments.metadata[attr])) {
					for (paramIn in methodOut.parameters) {
						if (paramIn.name eq "typename") {
							paramIn["enum"] = arguments.typenames;
						}
					}
				}
			}
		}

		return methodOut;
	}

	public struct function getSwaggerParameter(required struct metadata) {
		var paramOut = {
			"in" = structKeyExists(arguments.metadata, "in") ? arguments.metadata.in : "query",
			"name" = arguments.metadata.name,
			"description" = structKeyExists(arguments.metadata, "description") ? arguments.metadata.description : "",
			"required" = structKeyExists(arguments.metadata, "required") and arguments.metadata.required,
			"type" = structKeyExists(arguments.metadata, "swagger_type") ? arguments.metadata.swagger_type : "string"
		};

		if (structKeyExists(arguments.metadata, "swagger_format")) {
			paramOut["format"] = arguments.metadata.swagger_format;
		}
		if (structKeyExists(arguments.metadata, "default")) {
			paramOut["default"] = arguments.metadata.default;
		}
		if (structKeyExists(arguments.metadata, "enum")) {
			paramOut["enum"] = listToArray(arguments.metadata.enum);
		}

		return paramOut;
	}

	public struct function getSwaggerResponse(required string definition) {
		var def = "";
		var desc = "";

		if (isJSON(arguments.definition)) {
			return deserializeJSON(arguments.definition);
		}

		def = listFirst(trim(arguments.definition), ":");
		desc = listRest(trim(arguments.definition), ":");

		if (refind("^\[\]##", def)) {
			return {
				"schema" = {
					"properties" = {
						"items" = {
							"type" = "array",
							"items" = {
								"$ref" = mid(def, "3", len(def))
							}
						},
						"page" = {
							"type" = "integer",
							"format" = "int32"
						},
						"pagesize" = {
							"type" = "integer",
							"format" = "int32"
						},
						"total" = {
							"type" = "integer",
							"format" = "int32"
						}
					}
				},
				"description" = desc
			}
		}
		else if (refind("^##", arguments.definition)) {
			// specific type as an item
			return {
				"schema" = {
					"$ref": def
				},
				"description" = desc
			};
		}
		else {
			return arguments.definition;
		}
	}

	public struct function getSwaggerDefinition(required string typename) {
		var o = application.fapi.getContentType(typename=arguments.typename);
		var properties = {};
		var prop = "";

		if (structKeyExists(o, "getSwaggerDefinition")) {
			return o.getSwaggerDefinition(typename=arguments.typename);
		}
		
		for (prop in application.stCOAPI[arguments.typename].stProps) {
			if (prop eq "objectid") {
				continue;
			}

			properties[prop] = {
				"type" = "string",
				"description" = application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="hint", default="")
			};

			switch (application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="ftType", default=application.stCOAPI[arguments.typename].stProps[prop].metadata.type)) {
			case "array":
				properties[prop].type = "array";
				properties[prop]["items"] = { "type" = "string", "format" = "uuid" };
				break;
			case "boolean":
				properties[prop].type = "boolean";
				break;
			case "datetime":
				properties[prop].type = "string";
				if (application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="ftShowTime", default=true)) {
					properties[prop]["format"] = "date-time";
				}
				else {
					properties[prop]["format"] = "date";
				}
				break;
			case "email":
				properties[prop]["format"] = "email";
				break;
			case "integer":
				properties[prop].type = "integer";
				break;
			case "numeric":
				properties[prop].type = "float";
				break;
			case "password":
				properties[prop].type = "password";
				break;
			case "richtext":
				properties[prop]["format"] = "html";
				break;
			case "url":
				properties[prop]["format"] = "url";
				break;
			case "uuid":
				properties[prop]["format"] = "uuid";
				break;
			}
		}

		return {
			"type" = "object",
			"description" = application.fapi.getContentTypeMetadata(typename=arguments.typename, md="hint", default=""),
			"allOf" = [{
				"$ref" = "##/definitions/ContentType"
			},{
				"type" = "object",
				"properties" = properties
			}]
		};
	}

}