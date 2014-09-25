angular.module('slug.traces.services', ['ngResource', 'slug.services.pretty_print'])
.factory 'ServiceTrace', ($resource, $state, Trace) ->
  ServiceTrace = $resource '/api/services/:service_id/traces/:id/:action/',
    { id: '@_id', service_id: -> $state.params.serviceId },
    search:
      method: 'GET',
      isArray: true,
      params:
        action: 'search_for_index'
    count:
      method: 'GET',
      isArray: false,
      params:
        action: 'count'
    wipe:
      method: 'DELETE',
      params:
        id: "all"
    redo:
      method: 'POST'
      params:
        action: 'redo'
  ServiceTrace::$trace = () -> new Trace(_id: @_id)
  ServiceTrace::$star = (f) -> @.$trace().$star(f)
  ServiceTrace::$unstar = (f) -> @.$trace().$unstar(f)
  ServiceTrace

.factory 'Trace', ($resource) ->
  $resource '/api/traces/:id/:action/', {id: '@_id'},
    uuid:
      method: 'GET'
      isArray: false
      params:
        action: 'find'
    search:
      method: 'GET',
      isArray: true,
      params:
        action: 'search_for_index'
    count:
      method: 'GET',
      isArray: false,
      params:
        action: 'count'
    star:
      method: 'POST',
      isArray: false,
      params:
        action: 'star'
    unstar:
      method: 'DELETE',
      isArray: false,
      params:
        action: 'star'
    wipe:
      method: 'DELETE',
      params:
        id: "all"
    redo:
      method: 'POST'
      params:
        action: 'redo'

angular.module('slug.traces', [
  'slug.traces.services',
  'slug.controllers', 'slug.services.filters',
  'ui.bootstrap.dropdownToggle',
  'ui.bootstrap.pagination', 'ui.bootstrap.collapse',
  'slug.directives.highlight'
])

.controller 'TracesNavigationCtrl', ($scope, $state, TracesFilter) ->
  $scope.filters.$promise.then (filters) ->
    $scope.filters.unshift new TracesFilter(
      _id: 3,
      name: 'Starred',
      icon: 'star',
      builtin: 'starred',
      tokens: [{
        key: 'starred',
        op: '=',
        value: true,
        active: true
      }]
    )
    $scope.filters.unshift new TracesFilter(
      _id: 2,
      name: 'Errors',
      icon: 'minus-sign',
      builtin: 'errors',
      tokens: [{
        key:'res.status',
        op:'>=',
        value: 400,
        active: true
      },
      {
        key:'res.status',
        op:'<=',
        value: 600,
        active: true
      }]
    )
    $scope.filters.unshift new TracesFilter(
      _id: 1,
      name: 'Traffic',
      icon: 'exchange',
      builtin: 'traffic',
      tokens: []
    )
    if name = $state.params.filter
      if filter = _.find($scope.filters, (f) -> f.builtin == name)
        $scope.search.use(filter)

  $scope.helpTemplate = "all_traces"

.controller 'TracesIndexCtrl',
($scope, Service, Trace, Search, TracesFilter, flash, $stateParams) ->
  $scope.search = new Search(Trace, $scope)
  $scope.services = Service.query()
  $scope.redo = (trace) ->
    redo = Trace.redo(_id: trace._id)
    redo.$promise

  $scope.filters = TracesFilter.query()

  $scope.serviceCode = (trace) ->
    $scope.services_hash ||= _.indexBy($scope.services, '_id')

    trace.$service_code ||= $scope.services_hash[trace.service_id]?.code()

  $scope.newFilter = (tokens) ->
    new TracesFilter(tokens: tokens, name: 'new filter')

  $scope.delete = (trace) ->
    trace.$remove ->
      $scope.search.remove(trace)
      flash.success = "Trace deleted"

  $scope.wipe = ->
    Trace.wipe -> $scope.search.do()
    flash.info = "All traces have been removed."

  $scope.load = (trace) ->
    unless trace.res?.body?
      Trace.get(id: trace._id, (full) -> angular.extend(trace, full))

.controller 'ServiceTracesIndexCtrl', ($scope, ServiceTrace, Search,
                                       flash, TracesFilter, Trace) ->
  $scope.search = new Search(ServiceTrace, $scope)

  $scope.redo = (trace) ->
    redo = Trace.redo(_id: trace._id)
    redo.$promise

  $scope.filters = TracesFilter.query()
  $scope.delete = (trace) ->
    trace.$trace().$remove ->
      $scope.search.remove(trace)
      flash.success = "Trace deleted"

  $scope.wipe = ->
    ServiceTrace.wipe -> $scope.search.do()
    flash.info = "All traces have been removed."

  $scope.helpTemplate = "traces"

  $scope.newFilter = (tokens) ->
    new TracesFilter(tokens: tokens, name: 'new filter')

  $scope.load = (trace) ->
    unless trace.res?.body?
      Trace.get(id: trace._id, (full) -> angular.extend(trace, full))

.controller 'TraceShowCtrl', ($scope, Trace, Service, $stateParams, flash) ->

  $scope.trace ||= Trace.get(id: $stateParams.traceId)

  $scope.trace.$promise.then (trace) ->
    $scope.service = Service.get(id: trace.service_id)

  $scope.redo   = -> $scope.trace.$redo(  -> flash.success = "Trace redone")
  $scope.delete = -> $scope.trace.$delete(-> flash.success = "Trace deleted")

  $scope.toggleStar = ->
    if $scope.trace.starred
      $scope.trace.$unstar()
    else
      $scope.trace.$star()


.controller 'TraceDestroyCtrl', ($scope, Trace, $stateParams) ->
  $scope.trace ||= Trace.get(id: $stateParams.traceId)

.controller 'TraceBodyCtrl', ($scope, prettyPrint) ->
  $scope.togglePrettyBody = ->
    if $scope.original
      $scope.body = $scope.original
      delete $scope.original
    else
      $scope.original = $scope.body
      $scope.body = prettyPrint($scope.contentType, $scope.body)

.directive 'slugTrace', ->
  scope:
    trace: "=slugTrace"
  templateUrl: (element, attrs) ->
    if attrs.expanded then '/traces/_expanded_trace.html' else '/traces/_trace.html'
  link: (scope, element, attrs) ->
    scope.response = scope.trace.res
    scope.request = scope.trace.req

.directive 'traceRequest', ->
  scope:
    request: "=traceRequest"
  templateUrl: (element, attrs) ->
    if attrs.expanded then '/traces/_expanded_request.html' else '/traces/_request.html'
  link: (scope, element, attrs) ->
    # FIXME: hehe, I-Case-Lover
    scope.contentType = scope.request.headers?['Content-Type']

.directive 'traceResponse', ->
  scope:
    response: "=traceResponse"
  templateUrl: (element, attrs) ->
    if attrs.expanded then '/traces/_expanded_response.html' else '/traces/_response.html'
  controller: ($scope) ->
    $scope.hasHeaders ||= (response) ->
      not _.isEmpty(response.headers)
  link: (scope) ->
    # FIXME: what if it is content-type ?
    if type = scope.response.headers?['Content-Type']
      scope.contentType = type.split(';')[0]

.directive 'traceHeaders', ->
  scope:
    headers: "=traceHeaders"
  templateUrl: '/traces/_headers.html'

.directive 'tracePipeline', ->
  scope:
    pipeline: "=tracePipeline"
  templateUrl: '/traces/_pipeline.html'
  controller: ($scope) ->
    $scope.hasResponse ||= (response) ->
      response.status || response.body || not _.isEmpty(response.headers)
