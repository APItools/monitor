angular.module('slug.home', [
  'ui.router', 'slug.service', 'slug.services.demo', 'angular-flash.service'
])
.config ($stateProvider, ServicesResolver) ->
  $stateProvider
    .state 'welcome',
      url: '/welcome'
      controller: 'HomeCtrl'
      templateUrl: '/home/index.html'
      resolve:
        services: ServicesResolver

.controller 'HomeCtrl', ($scope, services, DemoApis) ->
  $scope.services = services
  $scope.demos = DemoApis

.controller 'HomeDemoCtrl', ($scope, DemoService, flash, $analytics, $state) ->
  $scope.createDemo = ->
    DemoService.create $scope.demo, (service) ->
      flash.success = "#{service.name} created"
      $analytics.eventTrack('demo.created', demo: service.demo)
      $scope.service = service

  $scope.service =
    _($scope.services).find (service) -> service.demo == $scope.key

  $scope.servicePath = ->
    id = $scope.service?._id
    if id # FIXME: sry for hardcoring the app prefix,
          # but thre is no other way for now, not even the ui-sref works
      '/app' + $state.href('service.show', serviceId: id)

.directive 'slugToggleClass', ->
  restrict: 'A'
  link: (scope, element, attrs) ->
    element.on 'click', '.toggle-item', (event) ->
      element.toggleClass('opened')
