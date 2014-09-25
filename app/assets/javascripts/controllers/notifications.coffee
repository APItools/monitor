angular.module('slug.notifications', [
  'ngResource', 'slug.search', 'angular-flash.service',
  'infinite-scroll', 'slug.directives.filter'
])
.config ($stateProvider) ->
  $stateProvider
    .state 'notifications',
      url: '/notifications?filter&select'
      templateUrl: '/notifications/index.html'
      controller: 'NotificationsListCtrl'

.controller 'NotificationsNavigationCtrl', ($scope, $state, flash, EventsFilter) ->
  $scope.filters.$promise.then ->
    $scope.filters.unshift new EventsFilter(
      name: 'Middlewares',
      icon: 'cogs',
      builtin: true,
      tokens: [{key: 'channel', op: '=', value: 'middleware', active: true}]
    )
    $scope.filters.unshift new EventsFilter(
      name: 'Stats',
      icon: 'bar-chart',
      builtin: true,
      tokens: [{key: 'channel', op: '=', value: 'stats', active: true}]
    )
    $scope.filters.unshift new EventsFilter(
      name: 'Syslog',
      icon: 'desktop',
      builtin: true,
      tokens: [{key: 'channel', op: '=', value: 'syslog', active: true}]
    )
    $scope.filters.unshift new EventsFilter(
      name: 'Notifications',
      builtin: 'notifications',
      icon: 'asterisk',
      tokens: [
        { key: 'level', op: '@', value: 'error', active: true }
        { key: 'level', op: '@', value: 'alert', active: true }
        { key: 'level', op: '@', value: 'warn',  active: true }
        { key: 'level', op: '@', value: 'info',  active: true }
      ]
    )
    $scope.filters.unshift new EventsFilter(
      name: 'Errors',
      builtin: 'errors',
      icon: 'asterisk',
      tokens: [
        { key: 'level', op: '@', value: 'error', active: true }
        { key: 'level', op: '@', value: 'alert', active: true }
        { key: 'level', op: '@', value: 'warn',  active: true }
      ]
    )

    if name = $state.params.filter
      if filter = _.find($scope.filters, (f) -> f.builtin == name)
        $scope.search.use(filter)

  $scope.helpTemplate = "notifications"

.factory 'Event', ($resource) ->
  $resource '/api/events/:id/:action', {id: '@_id'},
    star: {
      method: 'POST',
      isArray: false,
      params:
        action: 'star'
    },
    unstar: {
      method: 'DELETE',
      isArray: false,
      params:
        action: 'star'
    },
    search: {
      method: 'GET',
      isArray: true,
      params: {}
    }
    count: {
      method: 'GET',
      isArray: false,
      params: {
        action: 'count'
      }
    }
    wipe: {
      method: 'DELETE',
      params: {
        id: "all"
      }
    }

.factory 'EventsFilter', ($resource) ->
  $resource '/api/filters/events/:id', id: '@_id'

.controller 'NotificationsListCtrl', ($scope, $state, Event, Search,
                                      flash, EventsFilter, $stateParams) ->
  $scope.selected_event = $stateParams.select
  $scope.search = new Search(Event, $scope)
  $scope.filters = EventsFilter.query()

  $scope.newFilter = (tokens) ->
    new EventsFilter(tokens: tokens, name: 'new filter')

  $scope.highlight = (event) ->
    Event.highlight({id: event._id }, {highlighted: true})

  $scope.wipe = ->
    Event.wipe -> $scope.search.do()
    flash.info = "All notifications have been removed."


