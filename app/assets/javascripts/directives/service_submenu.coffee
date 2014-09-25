angular.module('slug.service_submenu.service', [])
.constant 'ServiceSubmenu',
  service_submenu = # this is probably not cool as it will define var on file scope
    service: null
    show: true
    active: false
    isSelected: (service) -> service_submenu.service?._id == service?._id
    use: (service) -> service_submenu.service = service
    update: (service) -> service_submenu.use(service) if service_submenu.isSelected(service)

angular.module('slug.service_submenu', ['slug.service', 'slug.utils', 'slug.service_submenu.service'])
.factory 'ActiveDocsCheck',
  ($http, $state) ->
    (service_id = $state.params.serviceId) ->
      if service_id
        $http(method: 'GET', url: "/api/services/#{service_id}/docs")

.controller 'ServiceSubmenuCtrl', ($scope, $rootScope, $state, $loop,
                                   Service, ServiceSubmenu, ActiveDocsCheck, UserSettings) ->
    $scope.submenu = ServiceSubmenu
    $scope.config = UserSettings

    $scope.$watch(
      -> ServiceSubmenu.service
      (service) ->
        $scope.service_navigation = if service?._id then "/navigation/service.html" else "/navigation/all_services.html"
    )

    $rootScope.$on 'serviceReset', (event) ->
      ServiceSubmenu.use(null)

    $rootScope.$on 'serviceUpdated', (event, service) ->
      ServiceSubmenu.services = Service.query ->
        ServiceSubmenu.update(service)

    $scope.selectService = (service) ->
      unless service
        ServiceSubmenu.use(service)
        root = $state.current.name.replace('service.', '')
        state = $state.get(root)

        if state && state.parent != 'service'
          $state.transitionTo(state)
        else
          $state.transitionTo('services')
        return

      params = serviceId: service._id

      if $state.includes('service')
        $state.transitionTo($state.current.name, params)

      else
        scoped = $state.get('service.' + $state.current.name)

        if scoped
          $state.transitionTo(scoped, params)
        else
          $state.transitionTo('service.traces', params)

.directive 'serviceSubmenu', ->
    templateUrl: '/services/_submenu.html'
    controller: 'ServiceSubmenuCtrl'
    replace: true
