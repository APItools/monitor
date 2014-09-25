## super harcode fix for super harcode bug
## firefox would not change path if on some ocasions you use absolute url to history state
window.history.pushState(null, null, window.location.pathname)

## Chrome now truncates long messages - which sucks for angular
## Reference: http://stackoverflow.com/questions/22199564/chrome-truncates-error-messages-and-adds-omitted-in-window-onerror
###
window.onerror = (errorMsg, url, lineNumber, columnNumber, errorObject) ->
  errMsg = if (errorObject and errorObject.message) then errorObject.message else errorMsg
  console.log('Error: ' + errMsg) if errMsg.length >= 256
###

moment.lang 'en',
  relativeTime:
    future: 'in %s'
    past : (output) ->
      if output == 'a few seconds' then 'just now' else "#{output} ago"
    s : 'a few seconds'
    m : "a minute"
    mm : "%d minutes"
    h : "an hour"
    hh : "%d hours"
    d : "a day"
    dd : "%d days"
    M : "a month"
    MM : "%d months"
    y : "a year"
    yy : "%d years"

  longDateFormat :
    LT: "h:mm A UTC",
    L: "MM/DD/YYYY",
    LL: "MMMM Do YYYY",
    LLL: "MMMM Do YYYY LT",
    LLLL: "dddd, MMMM Do YYYY LT"

slug = angular.module "slug", [
  'slug.controllers', 'slug.services', 'slug.filters', 'slug.directives',
  'angular-flash.flash-alert-directive',
  'ui.router',
  'ui.bootstrap.tooltip', 'ui.bootstrap.popover', 'ui.bootstrap.typeahead',

  # 'ngAnimate',# 'ngAnimate-animate.css',
  # split functionality into modules
  'slug.analytics',

  'slug.dashboard', 'slug.dashboards',
  'slug.service', 'slug.active_docs', 'slug.home', 'slug.root',
  'slug.documentation',
  'slug.brain_middleware_specs'
]

# DISABLE TEMPLATE CACHING
#slug.run ($rootScope, $templateCache) ->
#  $rootScope.$on '$viewContentLoaded', ->
#    $templateCache.removeAll()

slug.run ($rootScope, $state, $stateParams) ->
  $rootScope.$state = $state

slug.config ($provide) ->
  $provide.decorator '$exceptionHandler', ($delegate, errorception) ->
    (exception, cause) ->
      $delegate(exception, cause)
      errorception(exception)

slug.config ($stateProvider, $locationProvider, $anchorScrollProvider) ->
  $locationProvider.html5Mode(true).hashPrefix('!')
  $anchorScrollProvider.disableAutoScrolling()

  $stateProvider
    .state 'search',
      url: '/search'
      templateUrl: '/search/index.html'
      controller: 'SearchCtrl'

    .state 'service.traces',
      parent: 'service'
      url: '/traces?filter'
      templateUrl: '/services/traces/index.html'
      controller: 'ServiceTracesIndexCtrl'

    .state 'traces',
      url: '/traces?filter'
      templateUrl: '/traces/index.html'
      controller: 'TracesIndexCtrl'

    .state 'trace',
      url: '/traces/:traceId'
      templateUrl: '/traces/show.html'
      controller: 'TraceShowCtrl'

    .state 'trace-uuid',
      url: '/traces/find/:traceUuid'
      resolve:
        trace: ($stateParams, Trace) ->
          Trace.uuid(id: $stateParams.traceUuid).$promise
      controller: (trace, $state) ->
        $state.go('trace', traceId: trace._id)

