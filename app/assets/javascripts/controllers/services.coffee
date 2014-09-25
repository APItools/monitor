
angular.module('slug.service', ['ngResource', 'ui.router', 'slug.service_submenu.service'])
.factory 'Service', ($resource, $location) ->
    Service = $resource '/api/services/:id', id: '@_id'
    Service::host = -> "#{@code()}-#{$location.host()}"
    Service::code = -> @endpoints[0]?.code
    Service

.constant 'ServicesResolver', (Service) ->
    Service.query().$promise
.constant 'ServiceResolver', ($stateParams, Service) ->
    Service.get(id: $stateParams.serviceId).$promise

.config ($stateProvider, ServicesResolver, ServiceResolver, ServiceSubmenu) ->
    services =
      service: ServiceResolver
      services: ServicesResolver
    $stateProvider
    .state 'services',
        url: '/services'
        templateUrl: '/services/index.html'
        controller: 'ServicesListCtrl'

    .state 'service-new',
        url: '/services/new'
        templateUrl: '/services/new.html'
        controller: 'ServiceNewCtrl'
        onEnter: ->
          ServiceSubmenu.show = false
        onExit: ->
          ServiceSubmenu.show = true

    .state 'service',
        url: '/services/:serviceId'
        abstract: true
        controller: 'ServiceCtrl'
        templateUrl: '/services/layout.html'
        resolve: services
        onEnter: (service) ->
          ServiceSubmenu.service = angular.copy(service) # because when editing it edits the submenu too
          ServiceSubmenu.active = true
        onExit: ->
          ServiceSubmenu.active = false

    .state 'service.landing',
        url: ''
        parent: 'service'
        controller: ($state, $stateParams) ->
          $state.go('service.traces', serviceId: $stateParams.serviceId)

    .state 'service.show',
        url: '/integration'
        parent: 'service'
        templateUrl: '/services/show.html'
        controller: 'ServiceShowCtrl'
        resolve: services

    .state 'service.demo',
        url: '/demo_calls'
        parent: 'service'
        templateUrl: '/services/demo_calls.html'
        controller: 'ServiceDemoCallsCtrl'

    .state 'service.edit',
        parent: 'service'
        url: '/edit'
        templateUrl: '/services/edit.html'
        controller: 'ServiceEditCtrl'

    .state 'service.destroy',
        parent: 'service'
        url: '/destroy'
        views:
          "@":
            templateUrl: '/services/destroy.html'
            controller: 'ServiceDestroyCtrl'

angular.module('slug.controllers.services', [
  'slug.services', 'slug.controllers', 'slug.stats',
  'ngResource', 'slug.services.demo'
])

.factory 'ServiceStatsDashboard', ($resource, $state) ->
  $resource '/api/services/:serviceId/stats/dashboard', {
    serviceId: -> $state.params.serviceId
  }

.factory 'ServicesDashboard', (Service, ServiceStatsDashboard, $q, $timeout) ->
  class ServicesDashboard
    constructor: ->
      @services = Service.query()
      @stats = {}

    when_ready: (f) ->
      @services.$promise.then(f)

    load_service_stats: (service_id) ->
      ServiceStatsDashboard.get(serviceId: service_id).$promise.then (stats) =>
        @stats[service_id] = stats

    refresh: ($scope) ->
      last_timeout = null

      update_stats = =>
        @load_all_stats().then ->
          last_timeout = $timeout(update_stats, 10000)

      $scope.$on '$destroy', ->
        $timeout.cancel(last_timeout)

      @when_ready(update_stats)

    load_all_stats: =>
      promises = for service in @services
        @load_service_stats(service._id)

      $q.all(promises)

.controller 'ServicesListCtrl', ($scope, ServicesDashboard) ->
  $scope.dashboard ||= new ServicesDashboard()
  $scope.dashboard.refresh($scope)

.controller 'ServiceDashboardCtrl', ($scope) ->
  stats = -> $scope.dashboard.stats[$scope.service._id]
  $scope.$watch(stats, (stats) -> $scope.stats = stats)

  $scope.template =
    chart:
      height: 150
    plotOptions:
      series:
        animation: false

.controller 'ServiceCtrl', ($scope, services, service, $state) ->
  $scope.services ||= services
  $scope.service = service

.controller 'ServiceDemoCallsCtrl', ($scope, service, DemoApis) ->
  $scope.demo = DemoApis[service.demo]

.controller 'ServiceShowCtrl', ($scope, $location, service, DemoApis) ->

  # FIXME: Put this on a service or something so we can reuse
  $scope.endpoint = service.endpoints?[0].code
  $scope.proxy_url = "#{$location.protocol()}://#{service.host?()}/"

  $scope.demo = DemoApis[service.demo]

  $scope.integration = if service.demo then 'demo' else 'normal'

  $scope.helpTemplate = "endpoints"
  $scope.copy = (node) ->
    text = node.textContent.trim()
    # TODO: this is not working
    clip = new ZeroClipboard()
    clip.setText(text)

.controller 'ServiceDestroyCtrl', (
  $scope, Service, $stateParams, flash, $location, $analytics
) ->
  $scope.service ||= Service.get(id: $stateParams.serviceId)
  $scope.destroy = ->
    flash.warning = 'Deleting Service ...'
    $scope.service.$remove (service) ->
      # FIXME: all this just to remove one element from the array?
      # BTW they are equal but not by identity,
      # so you can't use indexOf directly
      equals = _.partial(angular.equals, service)

      if for_removal = _($scope.services).find(equals)
        index = $scope.services.indexOf(for_removal)
        $scope.services.splice(index, 1)

      flash.info = 'Service deleted'
      $analytics.eventTrack('service.deleted', service_id: service._id)
      $location.path('/')

.controller 'ServiceNewCtrl', ($scope, Service, DemoApis, DemoService, $analytics) ->
  $scope.service_new = true
  $scope.service = new Service(endpoints: [{}])
  $scope.demos = DemoApis
  $scope.$emit('serviceReset')

  $scope.useDemo = (demo) ->
    DemoService.update($scope.service, demo)
    $analytics.eventTrack('demo.use', demo: demo)

.controller 'ServiceEditCtrl', (
  $scope, $state, $stateParams, Service, $location, $analytics, $rootScope
) ->
  $scope.service ||= Service.get(id: $stateParams.serviceId)
  $scope.suffix = $location.host()
  $scope.service_edit = true

  $scope.resetDemo = () ->
    delete $scope.service.demo
    delete $scope.service.logo

  $scope.save = ->
    $scope.service.$save (service) ->
      $state.go('service.show', serviceId: service._id).then ->
        $rootScope.$emit('serviceUpdated', service)
        $analytics.eventTrack('service.save', service_id: service._id)

.controller 'ServiceEndpointCtrl', ($scope, uuid) ->
  $scope.endpoint.code ||= uuid().substr(0, 8)
  $scope.original = angular.copy($scope.endpoint)

  $scope.edit = () ->
    $scope.editing = true

  $scope.apply = () ->
    $scope.original = angular.copy($scope.endpoint)
    $scope.editing = false

  $scope.cancel = () ->
    angular.extend($scope.endpoint, $scope.original)
    $scope.editing = false
