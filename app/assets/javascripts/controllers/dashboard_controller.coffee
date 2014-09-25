angular.module('slug.dashboard',
  ['ui.router', 'slug.stats', 'slug.notifications',
   'slug.service', 'slug.traces.services'])

.config ($stateProvider) ->
  $stateProvider.state 'dashboard',
    url: '/dashboard'
    templateUrl: '/dashboard/show.html'
    controller: 'DashboardCtrl'

.factory 'AggregatedDashboard', ($http, LoadChart, $timeout, $q, Stats) ->
  class AggeragedDashboard
    @traffic =
      title: 'All Traffic'
      projections: { count: true }
      metric: 'hits'
      range:
        granularity: 60
        type: 'relative'
        relative:
          end: 'now'
          start: 3600
    @time =
      title: 'Response Time'
      projections: { avg: true }
      metric: 'time'
      range:
        granularity: 60
        type: 'relative'
        relative:
          end: 'now'
          start: 3600
    @errors =
      title: 'Errors'
      projections: {avg: true, count: true}
      metric: 'status'
      statuses:
        $gte: 400
        $lt: 600
      range:
        granularity: 60
        type: 'relative'
        relative:
          end: 'now'
          start: 3600

    available:
      errors: @errors
      traffic: @traffic
      time: @time
    default: 'traffic'

    constructor: ->
      @load('traffic')

    colors:
      errors: '#AC3131'
      time: '#FFA500'
      traffic: '#317eac'

    hook: ($scope) =>
      $scope.$on('$destroy', @stop)

    stop: =>
      $timeout.cancel(@last_timeout)

    autoupdate: (dashboard, callback) ->
      @stop()

      update_stats = =>
        @load(dashboard, callback).then =>
          @last_timeout = $timeout(update_stats, 60 * 1000)

      update_stats()

    load: (what, callback) ->
      LoadChart(query: AggeragedDashboard[what], Stats)
        .then((stats) => @[what] = stats)
        .then(callback)

.controller 'DashboardCtrl', ($scope, $rootScope, AggregatedDashboard, Service, Event, Trace, jsonify) ->

  $rootScope.$emit('serviceReset')

  $scope.dashboards = new AggregatedDashboard()
  $scope.dashboards.hook($scope)

  last_hour = (conditions) ->
    timestamp = moment().subtract('hour', 1).unix()
    timeframe = { _created_at: { $gte: timestamp } }
    angular.extend(timeframe, conditions || {})
    jsonify(timeframe)

  $scope.middleware_errors = Event.count(query: last_hour(level: 'error'))
  $scope.request_errors    = Trace.count(query: last_hour(res: {status: {$gte: 400}}))

  $scope.services = Service.query()

  $scope.selectDashboard = (key) ->
    $scope.selected_dashboard = key
    $scope.color = $scope.dashboards.colors[key]

    $scope.dashboards.autoupdate key, (dashboard) ->
      $scope.dashboard = dashboard

  $scope.selectDashboard($scope.dashboards.default)


  last_events_query = jsonify(level: {$in: ['error', 'alert', 'warn', 'info']})
  $scope.last_notifications =
    Event.query(query: last_events_query, reversed: true, per_page: 7)

  $scope.last_traces = Trace.query(reversed: true, per_page: 7)

  last_stats_query = jsonify(channel: 'stats')
  $scope.last_stats = Event.count(query: last_stats_query)
