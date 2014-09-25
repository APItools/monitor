RickshawHover = Rickshaw.Class.create(Rickshaw.Graph.HoverDetail, {
  render: (args) ->
    $element = $(this.element)
    graph = this.graph
    points = args.detail.sort((a, b) -> a.order - b.order)
    $label = $('<div/>', class: 'super-label')
    for d,i in points
      if d.formattedYValue and $.isNumeric(d.value.y)
        $label.append($('<div/>', class: 'title').html(d.formattedXValue)) if i == 0

        line = $('<div/>')
          .append($('<div/>', class: 'swatch').css('background-color', d.series.color))
          .append($('<span/>').html(d.name + ": "))
          .append($('<span/>', class: 'value').html(d.formattedYValue))


        $label.append(line)

        dot = $('<div/>', class: 'dot active')
              .css('border-color', d.series.color)
              .css('top', graph.y(d.value.y0 + d.value.y) + 'px')

        $element.append(dot)

    $label.addClass('left')
    $element.append($label)

    this.show()
    leftAlignError = this._calcLayoutError([$label[0]])
    if leftAlignError > 0
      $label.removeClass('left').addClass('right')
      rightAlignError = this._calcLayoutError([$label[0]])
      if rightAlignError > leftAlignError
        $label.removeClass('right').addClass('left')

    label_height = $label.height()
    $label.css('top', Math.max(0, Math.min(args.mouseY - label_height / 2, graph.height - label_height - 20)))
})

angular.module('slug.stats', ['slug.utils', 'ngResource', 'slug.utils'])

.directive "rickshaw", (RickshawSeries, $window, $compile, defer) ->
  restrict: "A"
  template: "<div class='graph'></div>"
  link: (scope, element, attrs) ->
    series = [data: [{x:0, y:0}]] # dummy data needed for area renderer
    parent = element.parent()

    graph_height = attrs.rickshawHeight
    graph_width  = attrs.rickshawWidth
    renderer     = attrs.rickshawRenderer    or 'line'
    strokeWidth  = attrs.rickshawStrokeWidth or 1

    graph = new Rickshaw.Graph(
      height: graph_height,
      width: graph_width,
      renderer: renderer,
      strokeWidth: strokeWidth
      element: element.find('.graph')[0],
      interpolation: 'linear'
      stroke: true
      series: series
      min: 0
      padding: {
        top: 0.1,
        bottom: 0.1
      }
    )

    # Add some ranges to empty graphs
    oldDomain = graph.renderer.domain
    graph.renderer.domain = (data) ->
      domain = oldDomain.call(this, data)
      if domain.y[0] == domain.y[1]
        # TODO: evaluate if we also need domain.y[0] -= 12 (so the graph shows centered on 0-data graphs)
        # domain.y[0] -= 12
        domain.y[1] += 12
      domain

    xAxis = new Rickshaw.Graph.Axis.Time(
      graph: graph
      timeFixture: new Rickshaw.Fixtures.Time()
    )
    xAxis.render()

    yAxis = new Rickshaw.Graph.Axis.Y(
      graph: graph
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT
    )
    yAxis.render()

    hoverDetail = new RickshawHover(
      graph: graph
      xFormatter: (x) ->
        d3.time.format('%A, %b %e, %H:%M UTC')(new Date(x*1000))
    )

    lastDimensions  = null
    dimensions = null

    resize = ->
      lastDimensions = dimensions
      dimensions = getAvailableDimensions()

      unless angular.equals(dimensions, lastDimensions)
        graph.configure(height: dimensions.height, width: dimensions.width)

    getAvailableDimensions = ->
      # hide plot and maximizers
      parent.children().hide()

      newHeight =  graph_height or (parent.height() - (element.outerHeight(true) - element.height()))
      newWidth  =  graph_width  or (parent.width()  - (element.outerWidth(true)  - element.width()))

      parent.children().show()

      return { height: newHeight, width: newWidth }

    graph.onUpdate -> defer -> resize()

    graph.onConfigure -> graph.update()

    triggerUpdate = _.debounce((-> graph.update()), 50)

    window = angular.element($window)
    window.bind 'resize', triggerUpdate
    scope.$on '$destroy', -> window.unbind('resize', triggerUpdate)

    graph.render()

    # Update rickshaw data when the analytics data changes
    scope.$watch attrs.rickshaw, (analytics) ->
      newSeries = RickshawSeries(analytics, renderer, attrs.rickshawColor)
      return unless newSeries

      for item,i in newSeries
        series[i] = item

      series.pop() while series.length > newSeries.length

      graph.update()

.directive "rickshawMaximizer", ($modal) ->
  restrict: "A"
  template: "<i class='icon icon-resize-full rickshaw-maximizer' title='Maximize'></i>"
  link: (scope, element, attrs) ->
    graph        = element.siblings('[rickshaw]')

    element.on 'click', ->
      modal = $modal.open
        templateUrl: '/stats/maximized.html',
        controller: 'MaximizedStatsCtrl',
        scope: scope
        backdrop: 'static',
        windowClass: 'modal modal-full-graph modal-fill-flex modal-slug',
        resolve:
          analytics:      -> graph.attr('rickshaw')
          color:          -> graph.attr('rickshaw-color')
          renderer:       -> graph.attr('rickshaw-renderer') or 'line'
          strokeWidth:    -> graph.attr('rickshaw-stroke-width') or 1

.controller 'MaximizedStatsCtrl', ($scope, $timeout,
                                   analytics, color, renderer, strokeWidth) ->

  $scope.close        = $scope.$close
  $scope.color        = color
  $scope.renderer     = renderer
  $scope.strokeWidth  = strokeWidth

  $scope.$watch analytics, (analytics) ->
    $scope.analytics = analytics

.factory 'RickshawSeries', (RickshawColor) ->
  (analytics, renderer, color) ->
    return null unless analytics

    normalized_query = analytics.normalized_query
    resolution       = normalized_query.range.granularity
    start            = normalized_query.range.start

    for serie in analytics.results
      # Override last zero with previous value
      if serie.data[serie.data.length-1] == 0
        serie.data[serie.data.length-1] = serie.data[serie.data.length-2]

      data = for value, i in serie.data
        x: start + i * resolution
        y: value

      name = serie.metric
      [serie_color, stroke_color] = RickshawColor(name, color, renderer)

      color: serie_color
      stroke: stroke_color
      data: data
      name: name

.factory 'StringToColor', ->
  (str) ->
    hash = 0
    for i in [0..str.length-1] by 1
      hash = str.charCodeAt(i) + ((hash << 3) - hash)
    color = Math.abs(hash).toString(16).substring(0, 6)

    "##{'000000'.substring(0, 6 - color.length)}#{color}"

.factory 'RickshawColor', (StringToColor) ->
  (serie_name, color, renderer) ->
    serie_color = color or StringToColor(serie_name)
    stroke_color = serie_color
    if renderer == 'area'
      serie_color = d3.interpolateRgb(serie_color, 'white')(0.7)
    [serie_color, stroke_color]


.factory 'ServiceStats', ($resource, $state) ->
  $resource '/api/services/:serviceId/stats/analytics', {
    serviceId: -> $state.params.serviceId
  }

.factory 'Stats', ($resource) ->
  $resource '/api/stats/analytics', {}

.factory 'LoadChart', ($q, ServiceStats, jsonify) ->
  group_by = (group) ->
    [!!group.methods, !!group.paths, !!group.statuses, !!group.service]

  range = (query) ->
    rng = query.range
    rng = angular.copy(rng[rng.type])
    angular.extend(rng, granularity: query.range.granularity)

  query = (query) ->
    pluck = (array) ->
      if _.isArray(array) then _(array).pluck('value') else array || []

    methods = if query.methods then _(query.methods).keys() else []
    methods = '*' if methods.length == 0

    metrics = [query.paths]
    metrics.push(query.statuses) if query.metric == 'status'

    metrics = for metric in metrics
      names = pluck(metric)
      names = '*' if _.isArray(names) && names.length == 0
      names

    metrics.unshift(methods)

    projections = for name, enabled of query.projections
      name if enabled

    query: jsonify
      metrics: metrics
      projections: _.filter(projections, _.identity)
      range: range(query)
      metric: query.metric
      group_by: group_by(query.group_by or {})

  (chart, resource = ServiceStats) ->
    deferred = $q.defer()
    promise = deferred.promise

    unless chart
      deferred.reject("Missing chart")
      return promise

    stats = query(chart.query)

    return resource.get(stats).$promise
