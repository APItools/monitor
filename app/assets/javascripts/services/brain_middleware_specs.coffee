angular.module('slug.brain_middleware_specs', ['ui.router', 'ngResource'])

.factory 'BrainMiddlewareSpec', ($resource) ->
  $resource '/api/brain/middleware_specs/:id', id: '@_id',

    search:
      method: 'GET'
      url: '/api/brain/middleware_specs/search'
      endpoint: '@_endpoint'
      q: '@_q'
      per_page: '@_per_page'
      page: '@_page'
      isArray: true

