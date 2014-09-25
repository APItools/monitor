angular.module('slug.active_docs', ['slug.service'])

.config ($stateProvider) ->
  $stateProvider
    .state 'service.docs',
      parent: 'service'
      url: '/docs'
      templateUrl: '/active_docs/index.html'
      controller: 'ActiveDocsCtrl'

    .state 'service.docs.operation',
      parent: 'service.docs'
      url: '/:operationGuid'
      controller: 'ActiveDocsOperationCtrl'
      templateUrl: '/active_docs/index.html'

.factory 'ActiveDocsOperation',
  ($http, $state) -> (request, service_id = $state.params.serviceId) ->
    params = method: request.method, path: request.uri
    $http(
      method: 'GET',url: "/api/services/#{service_id}/operation",params: params)

.controller 'ActiveDocsCtrl', ($scope, service) ->
  $scope.resource =
    name: service.name
    system_name: service.code()
    path: "/api/services/#{service._id}/docs"
    domain: service.host()

.directive 'preventDocsLoad', ($window) ->
  compile: (element, attrs, transclude) ->
    src = attrs.preventDocsLoad

    hasDocs = $window.ThreeScale?.APIDocs?

    if not hasDocs
      replacement = angular.element('<script/>').attr(src: src)
      element.replaceWith(replacement)


.directive 'activeDocs', ($state, $window) ->
  LOADED_EVENT = 'resources:loaded'
  HEADING_CLASS = '.apidocs-heading'
  scope:
    resources: "=activeDocs"
  link: (scope, element, attrs) ->
    element.addClass('api-docs-wrap')
    element.on 'click', HEADING_CLASS, (e) ->
      heading = angular.element(event.target).closest(HEADING_CLASS)
      content = heading.siblings('.content')

      if not content.is(':visible') # opening it
        params = operationGuid: content.data('operation-id')
        $state.go('service.docs.operation', params)

    APIDocs = ThreeScale.APIDocs
    APIDocs.account_type = 'provider'
    APIDocs.init(scope.resources)

    APIDocs.jQuery.subscribe LOADED_EVENT, ->
      operation = element.find(
        "[data-operation-id='#{$state.params.operationGuid}']")
      APIDocs.Docs.expandOperation operation, ->
        win = angular.element($window)
        win.scrollTop(operation.position().top)

    scope.$on '$destroy', ->
      APIDocs.jQuery.unsubscribe(LOADED_EVENT)

.directive 'docsLink', ($state, ActiveDocsOperation, flash) ->
  restrict: 'A'
  priority: -1
  scope:
    trace: "=docsLink"
  link: (scope, element, attrs) ->
    trace = scope.trace

    afterResolvingTrace = (trace) ->
      service_id = trace.service_id

      operation = null

      changeState = (res) ->
        $state.go(
          'service.docs.operation',
          serviceId: service_id,
          operationGuid: res.data.guid)

      reportFail = (err) ->
        flash.error = err.data.error

      element.on 'mouseenter', ->
        operation ||= ActiveDocsOperation(trace.req, service_id)

      element.on 'click', ->
        operation.then(changeState, reportFail)
        return false

    if trace.$promise # expanded traces have a promise
      trace.$promise.then(afterResolvingTrace)
    else              # list traces have a resolved trace
      afterResolvingTrace(trace)






