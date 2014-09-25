## This module follows new organization of logic,
# one file should contain all the related things
# to the module (routes, controllers, directives)
angular.module(
  'slug.dashboards', ['ngResource', 'slug.service', 'slug.stats'])
    .config ($stateProvider) ->
      $stateProvider.state 'service.analytics',
        parent: 'service'
        url: '/analytics'
        templateUrl: '/analytics/index.html'
        controller: 'DashboardsCtrl'

.factory 'Dashboard', ($resource, $state) ->
  $resource '/api/services/:serviceId/dashboards/:id/', {
    id: '@_id', serviceId: -> $state.params.serviceId }

.factory 'Metrics', ($resource) ->
  $resource('/api/stats/metrics')

.controller 'DashboardsCtrl', ($scope, Dashboard) ->
  $scope.dashboards = Dashboard.query()

  $scope.select = (dashboard) ->
    $scope.current_dashboard = dashboard

.controller 'ChartController', ($scope, LoadChart, $timeout) ->
  $scope.blueprint = $scope.window.blueprint
  $scope.chart = $scope.window.chart

  last_timeout = null

  $scope.$on '$destroy', ->
    $timeout.cancel(last_timeout)

  update = ->
    chart = $scope.chart
    LoadChart(chart).then (stats) ->
      $scope.stats = stats
      granularity  = chart.query.range.granularity
      last_timeout = $timeout(update, granularity * 1000)

  update() # kick off auto updating

.controller 'CurrentDashboardCtrl', ($scope, $modal, flash) ->
  $scope.blueprint =
    type: 'normal'
    charts: [
      {type: 'expanded'}
      {type: 'normal'}
      {type: 'normal'}
    ]

  charts = -> $scope.current_dashboard.charts
  $scope.$watch charts, (dashboard_charts) ->
    $scope.windows = for blueprint, index in $scope.blueprint.charts
      { blueprint: blueprint, chart: dashboard_charts?[index] }

  $scope.editChartDialog = (chart, callback) ->
    dialog = $modal.open
      backdrop: true
      keyboard: true
      windowClass: 'modal modal-slug chart-edit modal-tall'
      backdropClick: false
      templateUrl: '/dashboards/chart.html'
      controller: 'DashboardEditChartDialogCtrl'
      resolve:
        chart: -> angular.copy(chart)

    dialog.result.then (result) ->
      if result or _.isNull(result)
        callback?(result)

  $scope.saveDashboard = ->
    $scope.current_dashboard.$save ->
      flash.success = "Dashboard saved"

  $scope.addChart = (position, chart) ->
    dashboard = $scope.current_dashboard
    charts = dashboard.charts
    #lua serializes [] as {}
    charts = dashboard.charts = [] if _.isEmpty(charts)

    newChart = position: position, plot: chart, $new: true, name: 'New Chart'

    $scope.editChartDialog newChart, (chart) ->
      dashboard.charts[position] = chart
      delete chart.$new
      $scope.saveDashboard()

  $scope.editChart = (chart) ->
    dashboard = $scope.current_dashboard
    charts = dashboard.charts

    $scope.editChartDialog chart, (updated) ->
      index = charts.indexOf(chart)
      charts[index] = updated
      $scope.saveDashboard()

.controller 'DashboardEditChartDialogCtrl', (
  $scope, chart, Metrics, LoadChart
) ->
  $scope.save = -> $scope.$close(chart)
  $scope.close = -> $scope.$close(false)
  $scope.delete = -> $scope.$close(null)

  default_query = {
    projections: {avg: true, count: true}
    paths: []
    methods: {}
    statuses: []
    metric: 'time'
    range:
      granularity: 60
      type: 'relative'
      absolute:
        start: moment().subtract(1, 'day').unix()
        end: moment().unix()
      relative:
        end: 'now'
        start: 3600
    group_by: { }
  }

  $scope.chart = chart
  $scope.query = chart.query =
    angular.extend({}, default_query, chart.query)
  $scope.absolute = { start: moment()}
  $scope.relative = {end: 'now', start: 3600}

  $scope.startDate = (seconds) ->
    moment().subtract(seconds, 'seconds').toDate()

  $scope.preview = ->
    LoadChart(chart).then (template) ->
      $scope.analytics = template

  $scope.preview()

  hr = 60*60
  $scope.available =
    ranges: [
      { length: 30*60, label: '30 min', title: '30 minutes' }
      { length: 60*60, label: '60 min', title: '1 hour' }
      { length: 3*hr, label: '3 hr', title: '3 hours' }
      { length: 6*hr, label: '6 hr', title: '6 hours' }
      { length: 12*hr, label: '12 hr', title: '1/2 day' }
      { length: 24*hr, label: '24 hr', title: '1 day' }

      { length: 7*24*hr, label: '1 wk', title: '1 week' }
    ]
    granularities: [
      { granularity: 10, label: '10 sec', tooltip: '10 seconds increments' }
      { granularity: 60, label: '1 min', tooltip: '1 minute increments' }
      { granularity: 3600, label: '1 hr', tooltip: '1 hour increments' }
      { granularity: 86400, label: '1 day', tooltip: '1 day increments' }
    ]
    metrics: Metrics.query()

  $scope.available.metrics.$promise.then (metrics) ->
    $scope.metrics = _(metrics).indexBy('key')

.controller 'DashboardsNavigationCtrl', ($scope, Dashboard, flash) ->
  $scope.helpTemplate = "analytics"

  charts =
    statuses:
      plot:
        type: 'big'
      position: 0
      name: 'Statuses'
      query:
        methods: []
        paths: []
        statuses: []
        group_by:
          statuses: true
        metric: "status"

        projections: {count: true}
        range:
          type: 'relative',
          granularity: 60
          relative:
            end: 'now'
            start: 1800

    traffic:
      plot:
        type: 'small'
      position: 1
      name: 'Traffic'
      query:
        methods: []
        paths: []
        statuses: []
        group_by:
          paths: true
          methods: true
        metric: "hits"

        projections: {count: true}

        range:
          type: 'relative',
          granularity: 60
          relative:
            end: 'now'
            start: 1800

    methods:
      plot:
        type: 'small'
      position: 2
      name: 'Methods average time'
      query:
        methods: []
        paths: []
        statuses: []
        group_by:
          methods: true
        metric: "time"

        projections: {avg: true}

        range:
          type: 'relative',
          granularity: 60
          relative:
            end: 'now'
            start: 1800

  $scope.dashboards.$promise.then (dashboards) ->
    dashboard = dashboards[0]

    unless dashboard
      defaults = [charts.statuses, charts.traffic, charts.methods]
      dashboard =
        $scope.emptyDashboard(name: 'default dashboard', charts: defaults)
      dashboard.$save ->
        dashboards.push(dashboard)

    $scope.select(dashboard)

  $scope.emptyDashboard = (attributes) ->
    new Dashboard(attributes)

  $scope.addEmptyDashboard = (attributes) ->
    return unless $scope.canAbortEdit()

    dashboard = $scope.emptyDashboard(attributes)

    $scope.dashboards.push(dashboard)
    $scope.edit(dashboard)

  original_select = $scope.select
  $scope.select = (dashboard) ->
    $scope.abort()
    original_select(dashboard)

  $scope.edit = (dashboard) ->
    $scope.editing = angular.copy(dashboard)
    $scope.editing.$original = dashboard

  $scope.isEditing = (dashboard) ->
    $scope.editing?.$original == dashboard

  $scope.delete = (dashboard) ->
    dashboard.$delete ->
      $scope.remove(dashboard)
      flash.success = "Dashboard #{dashboard.name} removed"
      $scope.abort()

  $scope.canAbortEdit = ->
    original = $scope.editing?.$original
    if original then original._id? else true

  $scope.remove = (dashboard) ->
    $scope.dashboards = _($scope.dashboards).without(dashboard)

  $scope.save = (dashboard) ->

    angular.extend(dashboard, $scope.editing)

    dashboard.$save ->
      $scope.abort()
      $scope.select(dashboard)
      flash.success = "Dashboard #{dashboard.name} saved"

  $scope.abort = ->
    $scope.remove($scope.editing?.$original) unless $scope.canAbortEdit()
    $scope.editing = null

.factory 'UsedMethods', ($resource, $state) ->

  $resource('/api/services/:service_id/used_methods', {
    service_id: ->
      $state.params.serviceId
  })

.factory 'AutoCompletePaths', ($resource, $state) ->
  $resource('/api/services/:service_id/path_autocomplete', {
    service_id: ->
      $state.params.serviceId
  })


.controller 'ChartConditionsCtrl', ($scope, UsedMethods, AutoCompletePaths) ->

  $scope.$watch 'query', (query) ->
    # fix empty objects to arrays as lua serializes [] as {}
    for metric in ['statuses', 'paths']
      query[metric] = [] unless _.isArray(query?[metric])

  $scope.randomMethod = (method) ->
    method.$placeholder ||=
      _.shuffle(['GET', 'POST', 'PUT', 'PATH', 'DELETE'])[0]

  $scope.randomStatus = (status) ->
    status.$placeholder ||= _.shuffle([200, 201, 301, 302, 404, 500])[0]

  $scope.getAutocompletePaths = AutoCompletePaths.query()

  $scope.isMethodChecked = (method) ->
    $scope.query.methods[method]

  $scope.noMethodsAreChecked = ->
    anyChecked = _($scope.query.methods).find (v) -> v == true
    not anyChecked

  $scope.used_methods = UsedMethods.get (methods_resource) ->
    for method in methods_resource.methods
      $scope.query.methods[method] = true

  $scope.add = (collection) ->
    collection.push({})

  $scope.remove = (collection, element) ->
    index = collection.indexOf(element)
    collection.splice(index, 1)

.controller 'ChartProjectionsCtrl', ($scope) ->
  $scope.$watch 'query.metric', (metric) ->
    $scope.metric = metric

    $scope.available.metrics.$promise.then ->
      $scope.type = $scope.metrics[$scope.metric].type

  $scope.metricHasProjections = ->
    type = $scope.type
    type == 'set' or type == 'time'

  $scope.availableProjections = ->
    type = $scope.type
    return unless type

    percentiles = ['p50', 'p80', 'p90', 'p95', 'p99']
    all =
      set: ['avg', 'max', 'min' ] # , percentiles...]
      count: ['count']
      last: ['last']

    available = all[type]
    available

  $scope.noProjectionsAreChecked = ->
    query = $scope.query
    projections = $scope.availableProjections($scope.type)
    return not _(projections).find (proj) -> query.projections[proj] == true


