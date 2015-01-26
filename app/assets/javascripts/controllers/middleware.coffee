angular.module('slug.middlewares', [
  'ui.router', 'ui.bootstrap.modal', 'slug.service', 'slug.middleware_specs',
  'ui.codemirror', 'ui.sortable', 'slug.controllers', 'ngResource', 'slug.brain_middleware_specs'
])
.config ($stateProvider) ->
  $stateProvider
    .state 'service.middleware',
        parent: 'service'
        url: '/middlewares'
        templateUrl: '/pipeline/index.html'
        controller: 'PipelineCtrl'
        resolve:
          pipeline: (Pipeline, $stateParams) ->
            Pipeline.get(service_id: $stateParams.serviceId).$promise

    .state 'service.middleware.edit',
      parent: 'service.middleware'
      url: '/:middlewareUuid'
      controller: 'MiddlewareEditCtrl'

    .state 'service.middleware.destroy',
        parent: 'service.middleware'
        url: '/destroy'
        templateUrl: '/middlewares/destroy.html'
        controller: 'MiddlewareDestroyCtrl'

.directive 'middleware', ->
  template: """
    <div class="header">
      <strong tooltip="{{middleware.name}}" tooltip-append-to-body="true">{{ middleware.name | truncate: 35 }}</strong>
      <ul class="controls">
        <li><button class="btn-link" ng-click="select(middleware)">
          <i class="icon-pencil"></i>
        </button></li>
        <li><button class="btn-link" ng-click="toggle(middleware)">
          <i class="icon-{{middleware.active ? 'off' : 'ok-circle' }}"></i>
        </button></li>
        <li><button class="btn-link" ng-click="remove(middleware)">
          <i class="icon-trash"></i>
        </button></li>
      </ul>
    </div>
    <div class="body"><em tooltip="{{middleware.description}}" tooltip-append-to-body="true">{{ middleware.description | truncate: 100}}</em></div>


    """
  link: (scope, element, attrs) ->
    scope.$watch 'middleware.active', (active) ->
      element.toggleClass('on', !!active).toggleClass('off', !active)
    scope.$watch 'middleware == selected', (selected) ->
      element.toggleClass('selected', !!selected)
    scope.$watch 'middleware.$updated', (status) ->
      element.toggleClass('updated', !!status)
    scope.$watch 'middleware.$new', (status) ->
      element.toggleClass('new', !!status)

    element.addClass('middleware')

.factory 'Pipeline', ($resource) ->
  $resource '/api/services/:service_id/pipeline/', {
    service_id: '@service_id'
  }

.factory 'Middlewares', (DefaultMiddlewareCode, uuid, $q) ->
  class Middlewares
    constructor: (middlewares) ->
      pipeline = angular.copy(middlewares)

      @array = _.values(pipeline)
      @array = _(@array).sortBy (mid) -> mid.position

    addEmpty: ->
      empty =
        name: 'new middleware'
        description: 'You can edit this description.'
        code: DefaultMiddlewareCode
        uuid: uuid()
        active: true
        $new:  true

      @array.push(empty)

      empty

    replace: (original, updated) ->
      index = @array.indexOf(original)

      return @remove(original) unless updated

      if index >= 0
        updated?.$updated = true
        @array[index] = updated

      updated

    get: (uuid) ->
      UUIDEquals = (middleware) -> String(middleware.uuid) == String(uuid)
      _(@array).find(UUIDEquals)

    remove: (original) ->
      index = @array.indexOf(original)
      @array.splice(index, 1)

    valueOf: -> @array.length

    ready: (callback) ->
      promises = _.pluck(@array, '$promise')
      all = $q.all(promises)
      all.then(callback)
      all

    toPipeline: ->
      index = 0
      pipeline = { }

      for middleware in @array
        middleware.position = index++
        pipeline[middleware.uuid] = middleware

      pipeline

.factory 'TemporaryChanges', ->
  class TemporaryChanges
    constructor: ->
      @store = []

    new: (original) ->
      copy = { original: original, copy: null }
      @store.push(copy)
      copy

    find: (original) ->
      @get(original)?.copy || original

    get: (original) ->
      _(@store).find (s) -> s.original == original

    for: (original) ->
      @get(original) || @new(original)

    delete: (original) ->
      @store = _(@store).without(@get(original))

.service 'NewMiddleware', ($q, uuid, BrainMiddlewareSpec) ->
  (middleware_spec) ->
    deferred = $q.defer()

    middleware =
      $new: true
      $promise: deferred.promise
      uuid: uuid()
      name: middleware_spec.name
      spec_id: middleware_spec.id unless middleware_spec.empty
      description: middleware_spec.description

    brain_spec = BrainMiddlewareSpec.get id: middleware_spec.id, (brain_spec) ->
      middleware.code = brain_spec.code
      deferred.resolve(middleware)

    middleware

.controller 'PipelineCtrl', (
  $scope, $state, $stateParams, pipeline, Middlewares,
  flash, TemporaryChanges, $analytics, NewMiddleware
) ->

  $scope.pipeline = pipeline
  $scope.middlewares = new Middlewares(pipeline.middlewares)

  $scope.revertPipeline = ->
    $scope.middlewares = new Middlewares($scope.pipeline.middlewares)

  $scope.$watch 'middlewares.count()', (count) ->
    $scope.counterReset = {"counter-reset": "li #{count + 1}"}

  $scope.$on '$stateChangeSuccess', (
    event, toState, toParams, fromState, fromParams
  ) ->
    if fromState.name == 'service.middleware.edit' and toState.name == 'middleware'
      $scope.select(null)

  $scope.temporary_changes = new TemporaryChanges()

  $scope.addEmptyMiddleware = ->
    middleware = $scope.middlewares.addEmpty()
    $scope.select(middleware)
    $analytics.eventTrack('middleware.added.empty')

  $scope.select = (middleware) ->
    middleware = null if middleware == $scope.selected
    $scope.selected = middleware

    if middleware
      params = angular.extend($stateParams, middlewareUuid: middleware.uuid)
      $scope.middleware = middleware
      $state.transitionTo('service.middleware.edit', params, false)

    else
      $state.transitionTo('service.middleware', $stateParams)

  $scope.remove = (middleware) ->
    $scope.middlewares.remove(middleware)
    $analytics.eventTrack('middleware.removed', middleware: middleware.uuid)

  $scope.toggle = (middleware) ->
    middleware.active = !middleware.active
    $scope.select(null)
    $analytics.eventTrack('middleware.toggled', middleware: middleware.uuid)

  $scope.github =
    middleware: [
      {
        name:'HODOR',
        author: {
          name: 'kikito'
        },
        description: 'hodor, hodor, hodor'
      }
    ]

  $scope.updatedMiddlewares = ->
    middlewares = $scope.middlewares

    return {} unless middlewares?

    middlewares.toPipeline()

  $scope.pipelineChanged = ->
    middlewares = $scope.pipeline.middlewares
    return unless $scope.middlewares
    ! angular.equals(middlewares, $scope.updatedMiddlewares())

  $scope.updatePipeline = ->

    pipeline = $scope.pipeline

    pipeline.middlewares = $scope.updatedMiddlewares()

  $scope.savePipeline = (callback) ->
    flash.info = 'Waiting for middlewares..'
    $analytics.eventTrack('pipeline.saving')

    $scope.middlewares.ready ->
      flash.info = "Saving..."
      $scope.updatePipeline()

      $scope.pipeline.$save ->
        flash.success = "Pipeline changed"
        $scope.revertPipeline()
        $analytics.eventTrack('pipeline.saved')
        callback?($scope.middlewares)

  $scope.$on 'drag.start', ->
    $scope.$apply -> $scope.is_dragged = true
  $scope.$on 'drag.stop', ->
    $scope.$apply -> delete $scope.is_dragged

  $scope.sortOptions =
    axis: 'y'
    cursor: 'move'
    items: '> li.middleware'
    connectWith: '.middleware-list.local'

    stop: (event, ui, sortable) ->
      sortable.moved?.$updated = true

    receive:
      pre: (event, ui, state) ->
        spec = ui.item.scope().$eval('spec')
        return unless spec
        middleware = NewMiddleware(spec)

        sortable = $(event.target).data('ui-sortable')
        state.currentItem = sortable.currentItem
        state.index = state.currentItem?.index('.middleware')
        middleware.active = true
        state.moved = middleware

      post: (event, ui, state) ->
        # remove added item
        state.currentItem?.remove()
        $analytics.eventTrack('middleware.added', middleware: state.moved)

  $scope.helpTemplate = "pipeline"

.controller 'MiddlewareEditCtrl', ($scope, $state, $stateParams, $modal) ->
  $scope.middleware ||= $scope.middlewares.get($stateParams.middlewareUuid)

  changes = $scope.temporary_changes

  middleware = changes.find($scope.middleware)

  $scope.save = (uuid, updated_middleware) ->
    original = $scope.middlewares.get(uuid)
    $scope.middleware = $scope.middlewares.replace(original, updated_middleware)

  modal = $modal.open
    templateUrl: '/middlewares/edit.html'
    controller: 'MiddlewareFormCtrl'
    backdrop: 'static'
    windowClass: 'modal modal-fullscreen modal-slug'
    resolve:
      middleware: -> angular.copy(middleware)
      changes: -> changes.for($scope.middleware)
      savePipeline: -> $scope.savePipeline
      save: -> $scope.save

  $scope.close = (result) ->
    if result
      # force closing dialog (by opening another one)
    else # closing the dialog by normal close or save
      changes.delete($scope.middleware)
      $state.transitionTo('service.middleware', $stateParams, false)

  modal.result.then($scope.close)

.factory 'MiddlewareLog', ($resource, $state) ->
    $resource '/api/services/:serviceId/console/:middlewareUuid',
      serviceId: -> $state.params.serviceId
      middlewareUuid: -> $state.params.middlewareUuid



.controller 'MiddlewareFormCtrl', ($scope, $browser, $timeout, $state,
                                   middleware, save, savePipeline, changes,
                                   MiddlewareLog, $loop, moment) ->
  uuid = middleware.uuid
  $scope.middleware = middleware
  $scope.original = angular.copy(middleware)
  $scope.hasSpec = !!middleware.spec_id

  $scope.codemirror =
    lineNumbers: true
    lineWrapping: true
    tabSize: 2
    # FIXME: this is super silly, the modal height is animated and codemirror
    # initializes during that animation
    # so it thinks that parent container is super small and needs scrollbar
    # unfortunately it is not refreshed when the animation is finished
    # so thats why here comes the magic:
    onLoad: (editor) ->
      refreshCodemirror = -> editor.refresh()

      for time in [200..900] by 100
        $timeout(refreshCodemirror, time)

      $scope.$on('resize', refreshCodemirror)

  logs_since = moment().unix()

  $scope.clear_console = ->
    logs_since = moment().unix()

  logsLoop = $loop $scope, ->
    MiddlewareLog.query since: logs_since, (logs) ->
      $scope.logs = logs
      logsLoop.schedule()

  $scope.canBeShared = ->
    $scope.sameAsOriginal() && !middleware.$updated && !middleware.$new

  $scope.sameAsOriginal = ->
    angular.equals($scope.middleware, $scope.original)

  $scope.close = $scope.$close

  $scope.share = () ->
    $state.transitionTo('spec.share', middlewareUuid: $scope.middleware.uuid)

  $scope.save = ->
    save(uuid, $scope.middleware)
    $scope.close()

  $scope.saveMetaOnEnter = (target, keyCode) ->
    this[target] = false if keyCode == 13


  $scope.saveAndDeploy = ->
    updated = save(uuid, $scope.middleware)

    updateOriginal = (middlewares) ->
      $scope.middleware = middleware = middlewares.get(updated.uuid)
      $scope.original = angular.copy(updated)

    savePipeline(updateOriginal)

  $scope.dragOptions =
    start: (event, ui) -> ui.helper.addClass("dragged")
    handle: '.modal-header'

  $scope.delete = ->
    save(uuid)
    $scope.close()

  stopChanges = $scope.$on '$stateChangeStart', (
    event, toState, toParams, fromState, fromParams
  ) ->
    # the unless condition would keep multiple windows opened
    # has to be defered to next tick, if done in sync $broadcast fails
    # because scope is removed in the process
    $browser.defer -> $scope.$apply -> $scope.$dismiss()
    changes.copy = $scope.middleware

  $scope.isLogCollapse = false;


.service 'BrainMiddlewareSearch', (BrainMiddlewareSpec) ->

  (endpoint) ->
    helper = ->
      search.loading = true

      params =
        endpoint: endpoint
        query: search.query
        per_page: 4
        page: search.page

      specs = BrainMiddlewareSpec.search(params)

      specs.$promise.then (results) ->
        search.loading = false
        search.done = results.length == 0
        search.specs = search.specs.concat(results)

    search =
      find: ->
        search.page = 1
        search.specs = []
        helper()
      loadMore: ->
        search.page++
        helper()

.controller 'MiddlewareSpecBarCtrl', ($scope, MiddlewareSpec, BrainMiddlewareSearch) ->
  $scope.search = BrainMiddlewareSearch($scope.service.endpoints[0].url)
  $scope.search.find()

  $scope.dragOptions =
    connectToSortable: '.pipeline .middleware-list'
    #refreshPositions: true
    #containment: '.pipeline-container'
    # snap behaves too weird, would have to change inner html structure
    #snap: '.pipeline .middleware-list'
    #snapMode: 'inner'
    # appendTo weirly fucks up zIndex and it can't be fixed by zIndex property
    #appendTo: '.pipeline .middleware-list'
    helper: 'clone'
    distance: 0
    revert: 'invalid'
    start: (e, ui) ->
      source = $(e.target)
      ui.helper.css('max-width', source.width())
      $scope.$emit('drag.start')
    stop: ->
      $scope.$emit('drag.stop')

.controller 'LastTraceController', ($scope, ServiceTrace, $stateParams, flash) ->
  $scope.load_last_trace = ->
    delete $scope.last_trace
    $scope.loading = true
    ServiceTrace.query service_id: $stateParams.serviceId, per_page: 1, reversed: true, (traces) ->
      $scope.last_trace = traces[0]
      $scope.loading = false

  $scope.load_last_trace()

  $scope.redo = (trace) ->
    trace.$redo ->
      $scope.load_last_trace()
      flash.info = 'Redone'

  $scope.has_body = (obj) ->
    obj?.body?.length > 0

  $scope.content_type = (obj) ->
    obj?.headers?['Content-Type']
