component {

	public struct function getSwaggerAPI(required struct metadata, required string prefix, required array typenames, struct stSwagger={}) {
		var methodIn = {};
		var method = "";
		var handle = "";
		var path = "";
		var typename = "";
		var allowedAuth = listToArray(application.fapi.getConfig("api", "authentication", "public"));
		var thisauth = "";
		var i = 0;
		var tags = "";

		if (structIsEmpty(arguments.stSwagger)) {
			arguments.stSwagger = structKeyExists(application, "swaggerBase") ? application.swaggerBase : deserializeJSON(fileRead(expandPath("/farcry/plugins") & "/api/config/swagger.json"));
			arguments.stSwagger.info.version = listLast(arguments.metadata.fullname, ".");
			arguments.stSwagger.info.title = application.fapi.getConfig("general", "sitetitle", "") & (structKeyExists(arguments.metadata, "title") ? ": " & arguments.metadata.title : "");
			arguments.stSwagger.info.description = application.fapi.getContentType("configAPI").getView(webskin="displayIntroduction#arguments.stSwagger.info.version#", alternateHTML="");
			//arguments.stSwagger.host = application.fc.lib.seo.getCanonicalDomain(bUseHostname=true);
			arguments.stSwagger.schemes = listToArray(application.fapi.getConfig("api", "schemes", "http"));
			//arguments.stSwagger.basePath = "";
			arguments.stSwagger.produces = ["text/json","text/html"];
			arguments.stSwagger.paths = {};

			for (thisauth in allowedAuth) {
				switch (thisauth) {
					case "public":
						// no security
						break;
					case "basic":
						if (not structKeyExists(stSwagger, "securityDefinitions")) {
							stSwagger["securityDefinitions"] = {};
						}
						stSwagger["securityDefinitions"]["basic"] = { "type" = "basic" };
						break;
					case "key":
						if (not structKeyExists(stSwagger, "securityDefinitions")) {
							stSwagger["securityDefinitions"] = {};
						}
						stSwagger["securityDefinitions"]["api_key"] = {
							"type" = "apiKey",
							"name" = "Authorization",
							"in" = "header"
						};
						break;
					case "session":
						// no security in UI
						break;
					default:
						if (not structKeyExists(stSwagger, "securityDefinitions")) {
							stSwagger["securityDefinitions"] = {};
						}
						stSwagger["securityDefinitions"]["api_key"] = {
							"type" = "apiKey",
							"name" = "Authorization",
							"in" = "header",
							"x-custom-auth" = application.fapi.getConfig("api", "authentication", "public")
						};
						break;
				}
			}

			for (typename in arguments.typenames) {
				if (not structKeyExists(arguments.stSwagger.definitions, typename)) {
					arguments.stSwagger.definitions[typename] = getSwaggerDefinition(typename=typename);
				}
			}
		}

		if (structKeyExists(arguments.metadata, "functions")) {
			for (methodIn in arguments.metadata.functions) {
				if (structKeyExists(methodIn, "handle") and (not structKeyExists(methodIn, "document") or methodIn.document eq true)) {
					addSwaggerMethod(swagger=arguments.stSwagger, prefix=arguments.prefix, typenames=arguments.typenames, metadata=methodIn);
				}
			}
		}

		if (structKeyExists(arguments.metadata, "extends")) {
			getSwaggerAPI(metadata=arguments.metadata.extends, prefix=arguments.prefix, typenames=arguments.typenames, stSwagger=arguments.stSwagger, debug=1);
		}

		for (i=arrayLen(arguments.stSwagger.tags); i>0; i--) {
			if (listFindNoCase(tags, arguments.stSwagger.tags[i].name)) {
				arrayDeleteAt(arguments.stSwagger.tags, i);
			}
			else {
				tags = listAppend(tags, arguments.stSwagger.tags[i].name);
			}
		}

		return arguments.stSwagger;
	}

	public void function addSwaggerMethod(required struct swagger, required string prefix, required array typenames, required struct metadata) {
		var methodOut = {
			"parameters" = []
		};
		var paramIn = {};
		var attr = "";
		var definition = "";
		var handle = listToArray(trim(arguments.metadata.handle), " ");
		var typename = "";
		var altMethod = {};
		var expandTypename = 0;

		// method and path
		if (arrayLen(handle) eq 2) {
			handle[2] = arguments.prefix & handle[2];
		}
		else {
			handle[2] = arguments.prefix;
		}
		methodOut["x-method"] = lcase(handle[1]);
		methodOut["x-path"] = handle[2];
		if (structKeyExists(arguments.metadata, "operationID")) {
			methodOut["operationId"] = arguments.metadata.operationID;
		}
		else {
			methodOut["operationId"] = arguments.metadata.name;
		}

		if (structKeyExists(arguments.metadata, "displayname")) {
			methodOut["summary"] = arguments.metadata.displayname;
		}

		if (structKeyExists(arguments.metadata, "hint")) {
			methodOut["description"] = arguments.metadata.hint;
		}

		if (structKeyExists(arguments.metadata, "tags")) {
			methodOut["tags"] = listToArray(arguments.metadata.tags);
		}

		if (structKeyExists(arguments.metadata, "security") and arguments.metadata.security neq "none") {
			methodOut["security"] = {};
			methodOut["security"][arguments.metadata.security] = [];
		}

		if (structKeyExists(arguments.metadata, "permission")) {
			methodOut["x-permission"] = arguments.metadata.permission;
		}
		else {
			methodOut["x-permission"] = "public";
		}

		if (structKeyExists(arguments.metadata, "parameters") and arrayLen(arguments.metadata.parameters)) {
			for (paramIn in arguments.metadata.parameters) {
				if (structKeyExists(paramIn, "swagger_type") and paramIn.swagger_type eq "typename") {
					expandTypename = arrayLen(methodOut.parameters) + 1;
				}
				else if (structKeyExists(paramIn, "in") and paramIn.in eq "pre") {
					// these are not public parameters
				}
				else {
					arrayAppend(methodOut.parameters, getSwaggerParameter(paramIn));
				}
			}
		}

		methodOut["responses"] = {};
		for (attr in arguments.metadata) {
			if ((len(attr) eq 3 and isNumeric(attr)) or attr eq "default") {
				methodOut.responses[attr] = arguments.metadata[attr];
			}
		}

		for (typename in arguments.typenames) {
			arguments.swagger.definitions["#typename#"] = getSwaggerDefinition(typename=typename, forUpdate=false);
			arguments.swagger.definitions["#typename#Update"] = getSwaggerDefinition(typename=typename, forUpdate=true);
		}

		if (expandTypename) {
			for (typename in arguments.typenames) {
				altMethod = duplicate(methodOut);
				altMethod["x-path"] = subsituteTypeParameters(typename=typename, input=altMethod["x-path"]);
				altMethod["x-permission"] = subsituteTypeParameters(typename=typename, input=altMethod["x-permission"]);
				altMethod["summary"] = subsituteTypeParameters(typename=typename, input=altMethod["summary"]);
				altMethod["description"] = subsituteTypeParameters(typename=typename, input=altMethod["description"]);
				altMethod["tags"] = subsituteTypeParameters(typename=typename, input=altMethod["tags"]);

				for (attr in altMethod.responses) {
					altMethod.responses[attr] = subsituteTypeParameters(typename=typename, input=altMethod.responses[attr]);
					altMethod.responses[attr] = getSwaggerResponse(altMethod.responses[attr]);
				}

				for (paramIn in altMethod.parameters) {
					if (structKeyExists(paramIn, "schema")) {
						paramIn["schema"] = subsituteTypeParameters(typename=typename, input=paramIn.schema);
						structAppend(paramIn, getSwaggerResponse(paramIn.schema), true);
						structDelete(paramIn, "type");
					}
				}

				for (attr in altMethod.tags) {
					arrayAppend(arguments.swagger.tags, {
						"name" = attr
					});
				}

				if (not structKeyExists(arguments.swagger.paths, altMethod["x-path"])) {
					arguments.swagger.paths[altMethod["x-path"]] = {};
				}

				arguments.swagger.paths[altMethod["x-path"]][altMethod["x-method"]] = altMethod;

				structDelete(altMethod, "x-path");
				structDelete(altMethod, "x-method");
			}
		}
		else {
			for (attr in methodOut.responses) {
				methodOut.responses[attr] = getSwaggerResponse(methodOut.responses[attr]);
			}

			for (attr in methodOut.tags) {
				arrayAppend(arguments.swagger.tags, {
					"name" = attr
				});
			}

			for (paramIn in methodOut.parameters) {
				if (structKeyExists(paramIn, "schema")) {
					structAppend(paramIn, getSwaggerResponse(paramIn.schema), true);
					structDelete(paramIn, "type");
				}
			}

			if (not structKeyExists(arguments.swagger.paths, methodOut["x-path"])) {
				arguments.swagger.paths[methodOut["x-path"]] = {};
			}

			arguments.swagger.paths[methodOut["x-path"]][methodOut["x-method"]] = methodOut;

			if (not structKeyExists(arguments.swagger.paths, methodOut["x-path"])) {
				arguments.swagger.paths[methodOut["x-path"]] = {};
			}

			arguments.swagger.paths[methodOut["x-path"]][methodOut["x-method"]] = methodOut;

			structDelete(methodOut, "x-path");
			structDelete(methodOut, "x-method");
		}
	}

	public struct function getSwaggerParameter(required struct metadata) {
		if (structKeyExists(arguments.metadata, "location")) {
			arguments.metadata["in"] = arguments.metadata.location;
		}
		var paramOut = {
			"in" = structKeyExists(arguments.metadata, "in") ? arguments.metadata.in : "query",
			"name" = arguments.metadata.name,
			"description" = structKeyExists(arguments.metadata, "description") ? arguments.metadata.description : "",
			"required" = structKeyExists(arguments.metadata, "required") and arguments.metadata.required,
			"type" = structKeyExists(arguments.metadata, "swagger_type") ? arguments.metadata.swagger_type : "string"
		};

		if (structKeyExists(arguments.metadata, "in") and arguments.metadata.in eq "body") {
			if (structKeyExists(arguments.metadata, "swagger_schema")) {
				paramOut["schema"] = arguments.metadata.swagger_schema;
			}
			else {
				throw(message="Parameters in 'body' must define a swagger_schema");
			}
		}
		else {
			if (structKeyExists(arguments.metadata, "swagger_format")) {
				paramOut["format"] = arguments.metadata.swagger_format;
			}
			if (structKeyExists(arguments.metadata, "default")) {
				paramOut["default"] = arguments.metadata.default;
			}
			if (structKeyExists(arguments.metadata, "enum")) {
				paramOut["enum"] = listToArray(arguments.metadata.enum);
			}
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

		if (refind("^\[\]##\w", def)) {
			return {
				"schema" = {
					"properties" = {
						"items" = {
							"type" = "array",
							"items" = {
								"$ref" = "##/definitions/" & mid(def, 4, len(def))
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
			};
		}
		else if (refind("^##\w", arguments.definition)) {
			// specific type as an item
			return {
				"schema" = {
					"$ref": "##/definitions/" & mid(def, 2, len(def))
				},
				"description" = desc
			};
		}
		else if (refind("^\[\]##", arguments.definition)) {
			// specific type as an array
			return {
				"schema" = {
					"properties" = {
						"items" = {
							"type" = "array",
							"items" = {
								"$ref": mid(def, 3, len(def))
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
			};
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
			throw(message="Invalid response definition: #arguments.definition#");
		}
	}

	public struct function getSwaggerDefinition(required string typename, boolean forUpdate=false) {
		var o = application.fapi.getContentType(typename=arguments.typename);
		var properties = {};
		var prop = "";

		if (structKeyExists(o, "getSwaggerDefinition")) {
			return o.getSwaggerDefinition(argumentCollection=arguments);
		}

		if (not arguments.forUpdate) {
			properties["objectid"] = {
				"type" = "string",
				"format" = "uuid"
			};
			properties["typename"] = {
				"type" = "string",
				"enum" = [arguments.typename]
			};
		}

		for (prop in application.stCOAPI[arguments.typename].stProps) {
			if ((arguments.forUpdate and listFindNoCase("farcry.core.packages.types.types", application.stCOAPI[arguments.typename].stProps[prop].origin)) OR (not arguments.forUpdate and prop eq "objectid")) {
				continue;
			}

			properties[prop] = {
				"type" = "string",
				"description" = application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="hint", default="")
			};

			switch (application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="ftType", default=application.stCOAPI[arguments.typename].stProps[prop].metadata.type)) {
			case "array":
				properties[prop].type = "array";
				properties[prop]["items"] = { "$ref" = "##/definitions/ItemReference" };
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
			case "list":
				if (application.fapi.getPropertyMetadata(typename=arguments.typename, property=prop, md="ftSelectMultiple", default=false)) {
					properties[prop] = { "type" = "array", "items" = { "type"="string" } };
				}
				break;
			case "numeric":
				properties[prop].type = "number";
				properties[prop]["format"] = "float";
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
				properties[prop] = { "$ref"="##/definitions/ItemReference" };
				break;
			}
		}

		if (arguments.forUpdate) {
			return {
				"description" = "Update object for " & application.fapi.getContentTypeMetadata(typename=arguments.typename, md='displayname', default=arguments.typename),
				"properties" = properties
			};
		}
		else {
			return {
				"description" = application.fapi.getContentTypeMetadata(typename=arguments.typename, md="hint", default=""),
				"properties" = properties
			};
		}
	}

	public any function subsituteTypeParameters(required any input, required string typename) {
		var i = 0;

		if (isArray(arguments.input)) {
			for (i=1; i<=arrayLen(arguments.input); i++) {
				arguments.input[i] = subsituteTypeParameters(input=arguments.input[i], typename=arguments.typename);
			}

			return arguments.input;
		}
		else {
			arguments.input = replaceNoCase(arguments.input, "{typename}", arguments.typename, "ALL");
			arguments.input = replaceNoCase(arguments.input, "{typelabel}", application.fapi.getContentTypeMetadata(typename=arguments.typename, md="displayname", default=arguments.typename), "ALL");
			arguments.input = replaceNoCase(arguments.input, "{typehint}", application.fapi.getContentTypeMetadata(typename=arguments.typename, md="hint", default=""), "ALL");

			return arguments.input;
		}
	}

}