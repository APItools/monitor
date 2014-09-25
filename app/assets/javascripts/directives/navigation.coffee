angular.module('slug.directives.navigation', ['slug.filters'])

.controller 'MiddlewareNavigationCtrl', ($scope) ->
  $scope

.controller 'ServiceNavigationCtrl', ($scope) ->
  $scope

.directive 'middlewareNavigation', ->
  controller: 'MiddlewareNavigationCtrl',
  templateUrl: '/navigation/middleware.html'

.directive 'serviceNavigation', ->
  controller: 'ServiceNavigationCtrl',
  templateUrl: '/navigation/service.html'

.directive 'tracesNavigation', ->
  controller: 'TracesNavigationCtrl',
  templateUrl: '/navigation/traces.html'

.directive 'analyticsNavigation', ->
  controller: 'DashboardsNavigationCtrl',
  templateUrl: '/navigation/analytics.html'
