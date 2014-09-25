angular.module('slug.services.filters', ['ngResource'])

.factory 'TracesFilter', ($resource) ->
  $resource '/api/filters/traces/:id', id: '@_id'

.factory 'AnalyticsFilter', ($resource) ->
  AnalyticsFilter = $resource '/api/filters/analytics/:id', id: '@_id'
  angular.extend AnalyticsFilter.prototype,
    query: ->
      projections = @projections.map (p) -> p.name
      metrics = [@methods, @paths, @metrics].map (m) ->
        values = m.map (v) -> v.name
        switch values.length
          when 0 then '*'
          when 1 then values[0]
          else values

      query = range: @range, metrics: metrics, projections: projections
      JSON.stringify(query)
  AnalyticsFilter
