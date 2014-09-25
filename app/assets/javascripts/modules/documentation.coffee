angular.module('slug.documentation', ['ngResource'])
  .directive "docsRef", (Documentation) ->
    scope:
      docsRef: "@"
    link: (scope, element, attrs) ->
      element.attr("href", Documentation[scope.docsRef])

  .factory 'Documentation', () ->
    host = 'http://docs.apitools.com'

    home: host + '/docs/'
    middlewares: host + '/docs/pipeline/#middleware-api'
    pipeline: host + '/docs/pipeline/'
    tour: host + '/docs/tour/'
    getting_started: host + '/docs/using-services/ '
    notifications: host + '/docs/notifications/'
    active_docs: host + '/docs/active-docs/'
    analytics: host + '/docs/tour/#service-analytics'
    filters: host + '/docs/filters/'
    traces: host + '/docs/'
