This plugin provides a configurable and extendable API interface to the website
database.

# Basic Installation

Out of the box, you can expose CRUD operations on selected content types.

1. Add the plugin to your project as `api`.
2. Add a web server alias and CFML mapping for `/apidoc` to
   `/farcry/plugins/api/www`.
3. Edit the API configuration, and select the authentication mode (see below)
   to enforce on API access, and the content types to create endpoints for.
4. If you have enabled API key authentication, an Access Key (Webtop -> Admin
   -> Users & Roles -> API -> Access Keys).
5. View the interactive API documentation on the `/apidoc` URL.

# Authentication

## Public

You can enable public access to your API, but it is **strongly** recommended
that you only do this if you have modified the API to remove create / update /
delete operations.

## Basic HTTP

This authentication scheme validates requests using Basic HTTP Authentication
against users in the core FarCry user directory. Access to the built in
endpoints are checked against the user's view / create / edit / delete
permissions.

## API Key

This scheme checks the `Authorization` header for a valid API key. API keys
can be set up in the Webtop at Webtop -> Admin -> Users & Roles -> API ->
Access Keys. Access keys allow you to specify which operations the key can
perform with which content types.

## Stateless API Key

This scheme checks the `Authorization` header for a valid stateless API key. A stateless API key can be created by calling `application.fc.lib.api.getStatelessAPIKey(username[, expiry])`. This authentication mode requires a secret to be set in the `API` config - do not use the default secret in production deployments.

This scheme is appropriate for client side access to the API via JavaScript.

# Extending the API

## APIs

The plugin looks for `api` packages, using the standard FarCry extension model.
This means that it looks for components in the `packages/api` directories of
plugins and projects. These components become available as an API named for the
component.

This means that you can add extra endpoints to the `v1` API by creating a
`projects/your_project/packages/api/v2.cfc` component and extending
`farcry.plugins.api.packages.api.v2`. Alternatively, you can remove existing
endpoints from `v2` by creating that file and not extending the original.

All APIs should extend `farcry.plugins.api.packages.api.base`, either directly
or via `v1`. This base component provides several helper functions.

## Endpoint definitions

Functions in an API are exposed as an endpoint if it has a `handle` attribute,
specifying the HTTP method and path it should respond to.

### Handle

The `handle` attribute should be of the form:

    METHOD /path/for/endpoint

Handles can also have parameter names as directories, for example:

    GET /dmNews/{objectid}

In that case, all parameters should have a corresponding `path` argument in the
function. See `arguments`.

### Display name

The `displayname` attribute value is displayed to users of the API documentation.

### Hint

The `hint` attribute value is displayed to users as a description of the
endpoint in the API documentation. This value can contain Markdown.

### Tags

The `tags` attribute is a list of categories, and is used to organise endpoints
into logical groups in the API documentation.

### Responses

Attributes that are HTTP response codes (e.g. `200`), and `default`, are used
to define endpoint response data structures. They take the form of the
definition ID and a short description:

    #dmNews:A news item

The `default` response is used to define a fallback response that is sent when
there is any kind of issue with the request or response, and will usually be:

    #/definitions/FailedRequest:Failure

Other responses, e.g. `200`, are the "successfull" response types, and usually
specify a content type, e.g.:

    #dmNews:A news item

or array of a content type:

    []#dmNews:An array of news

### Permission

You can restrict access to an endpoint by specifying a `permission` attribute.
This attribute can be one of three types of value:

    public // can be accessed without authentication and by any authenticated user
    somevalue // can be accessed using HTTP authentication, if the user has that permission
    typename:somevalue // can be accessed by a logged in user with the specified permission on the specified type

### Deprecated

To mark and endpoint as being deprecated, add the `@deprecated true` decorator to the function.

#### Basic HTTP

You can add custom permissions using the permissions UI in the Webtop.

#### API Key

You can add custom permissions to the UI by extending `apiAccessKey` and adding
values to the `ftOperations` attribute of the `authorization` property.

### Parameters

Parameters are defined using the arguments of the function. At the very least,
the arguments **must** include any `handle` parameters as `path` type
arguments.

| Argument type | Notes                                                                                                                                                                      | Attributes                                                                             |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Path          | Must be required                                                                                                                                                           | `in="path" description="Documentation hint" swagger_type="..." swagger_format="..."`   |
| Query         |                                                                                                                                                                            | `in="query" description="Documentation hint" swagger_type="..." swagger_format="..."`  |
| Header        |                                                                                                                                                                            | `in="header" description="Documentation hint" swagger_type="..." swagger_format="..."` |
| Body          | This parameter will detect and parse JSON request bodies.                                                                                                                  | `in="body" swagger_schema="..."`                                                       |
| Form          |                                                                                                                                                                            | `in="body" description="Documentation hint" swagger_type="..." swagger_format="..."`   |
| Preprocessing | This parameter is not exposed as a an API argument, but is processed before the function is executed. If errors are logged, then the function itself will not be executed. | `in="pre" fn="..."`                                                                    |

For more information about `swagger_type` and `swagger_format` see the
[Swagger Parameter specifications](1). The body parameter `swagger_schema`
attribute can be a valid response value, or a response value with `Update`
appended to indicate that only non-system properties should be allowed, e.g.
`#dmNewsUpdate:Updatable news properties`.

## Endpoint helpers

Several helper functions are provided to make it easier to return well
formatted responses from endpoints:

### addError(required string code, string message, string detail, string field, string in, any debug, boolean clearContent=true)

You can see the built in error codes in `api.cfc`, or the API documentation.
The idea of these is that an API consumer can reference this code any time they
get an error response, and know that that code only applies in a specific
circumstance. If you use one of the defined error codes, a default message is
added automatically. For unexpected errors (i.e. in a cfcatch) always return a
`999` error, with a message.

This function can be called multiple times to add multiple errors to the
response.

| Argument     | Description                                                                                                                        |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| detail       | Longer information about the error.                                                                                                |
| field        | Useful for parameter validation - specify which field was invalid.                                                                 |
| in           | Useful for parameter validation - specify which type of parameter this was.                                                        |
| debug        | Only included in the response if `request.mode.debug` is true. Only the last debug value is returned.                              |
| clearContent | Can be set to false to allow data added to the response up to the this point to be included. Otherwise only the error is returned. |

### errorCount()

Returns the number of errors that have already been added to the response.

### setResponse(required any data)

Sets the entire response data object to be returned.

### addResponse(required string key, required any data)

Adds the specified value to the data object to be returned.

### clearResponse()

Clears the current set of data to be returned.

### getResponseObject(struct stObject, string typename, uuid objectid)

Used to convert a specified item into the format appropriate for the API.
_Either_ stObject _or_ typename and objectid are required.

### updateObject(struct stObject, struct stUpdate)

This function expects a FarCry object and a typeUpdate body (see body parameter
and swagger_schema). It updates the FarCry object from the data submitted in
the format expected by the API.

## Custom reponse / body schemas

Types enabled for the content type are added to the documentation automatically
but you can add more by copying `/farcry/plugins/api/config/swagger.json` to
your project and setting `application.swaggerBase` to the path on application
start.

## Custom API documentation introduction

Override the `configAPI/displayIntroductionV1.cfm` file in your project.
Additionally, you can add other webskins with that naming scheme for alternate
APIs.

## Custom error codes

Extend `farcry.plugins.api.lib.api` in your project, and set your own
`this.codeTypeHints` and `this.codes` values.

## Custom request processing

Parameter parsing, authentication, etc, are all things that are done by the
plugin before actually calling the endpoint function. You can add your own
steps (or modify the default steps) by:

- extending `farcry.plugins.api.lib.api` in your project
- adding a function that
  - accepts `req` and `res`
  - returns an array of structs that can be passed into `addError` if there
    are issues with the request
- customize the `this.requestProcessors` variable

## Best practices

### Parameter validation

At the start of an endpoint function, check the validity of the parameters,
and return errors. This includes the existance of requested objects, ranges
on numeric parameters (e.g. for pagination), acceptable sorting, etc.

[1]: http://swagger.io/specification/#parameterObject