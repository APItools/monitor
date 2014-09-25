angular.module('slug.services.pretty_print', [])
.factory 'prettyPrintJson', ->
    (string) ->
      json = angular.fromJson(string)
      angular.toJson(json, true)

.factory 'prettyPrint', (prettyPrintJson) ->
    extractContentType = (contentType) ->
      contentType.split(';')[0]

    (contentType, code) ->
      switch contentType && extractContentType(contentType)
        when 'application/json'
          prettyPrintJson(code)
        else
          code
