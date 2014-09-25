angular.module('slug.services', ['ngResource', 'slug.github', 'slug.search'])

.factory 'moment', ($window) ->
  $window.moment

.factory 'Middleware', ($resource) ->
  $resource '/api/middlewares/:uuid', uuid: '@uuid'

.factory 'toArray', ->
  (object) -> if _.isArray(object) then object else [object]

.factory 'uuid', ->
  ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
      r = Math.random()*16|0
      v = if c == 'x' then r else (r&0x3|0x8)
      v.toString(16)
