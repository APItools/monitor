angular.module('slug.directives.list', ['ui.bootstrap.collapse', 'ngAnimate'])

.controller 'SlugListItemController', ($scope)->
  $scope.slugListItemToggle = ->
    $scope.isOpen = !$scope.isOpen

.directive 'slugList', ->
  restrict: 'A'
  transclude: false
  link: (scope, element, attrs) ->
    element.addClass('slug-list')

.directive 'slugItem', ($location) ->
  restrict: 'A'
  controller: 'SlugListItemController'
  transclude: false

  link: (scope, element, attrs) ->
    # element.addClass('dn-fade-up') # use animate.css transitions

    scope.$watch "isOpen", (isOpen) ->
      element.toggleClass("opened", !!isOpen)

    scope.isOpen = scope.$eval(attrs.slugItemExpanded)
    item = scope.$eval(attrs.slugItem)

    if item && scope.isOpen
      anchor = angular.element('<a>', name: "list-item-#{ item._id }")
      element.prepend(anchor)
      $location.hash("list-item-#{item._id}")

    element.addClass('slug-item')

.directive 'heading', ->
  restrict: 'E'
  require: '^slugItem'
  template:
    """<div class="slug-item-heading" ng-transclude></div>"""
  replace: true
  transclude: true

.directive 'toggle', ->
  restrict: 'E'
  require: '^slugItem'
  template:
    """<div class="slug-item-toggle" ng-click="slugListItemToggle()"
    ng-transclude></div>"""
  replace: true
  transclude: true


.directive 'actions', ->
  restrict: 'E'
  require: '^slugItem'
  template:
    """<div class="slug-item-actions dropdown">
        <action-button></action-button>
        <ul class="group dropdown-menu slug-item-dropdown" ng-transclude></ul>
      </div>"""
  replace: true
  transclude: true
  link: (scope, element, attrs) ->
    scope.active_actions = 0
    scope.$on('actions.running', -> scope.active_actions += 1)
    scope.$on('actions.finished', -> scope.active_actions -= 1)

.directive 'actionButton', ->
  restrict: 'E'
  require: '^actions'
  replace: true
  template: """
      <button class="action-button dropdown-toggle">
      <i class="icon icon-cog" ng-class="{'icon-spin': active_actions > 0 }"></i></button>
    """

.directive 'actionItem', ->
  restrict: 'E'
  require: '^slugItem'
  template: """<li class="" ng-transclude></li>"""
  replace: true
  transclude: true

.directive 'action', ($compile) ->
  scope: true
  # use isolate scope
  compile: (element, attrs) ->
    element.addClass('action')
    _icon = angular.lowercase(attrs.icon)
    _text = attrs.text

    (scope, element, attrs) ->
      icon = angular.element("""<i class="icon {{ icon }}"/>""")
      $compile(icon)(scope)
      element.append(icon)
      scope.icon = _icon

      if _text
        text = angular.element("""<span> {{ text }}</span>""")
        $compile(text)(scope)
        icon.append(text)
        scope.text = _text

.directive 'actionCall', ->
    link: (scope, element, attrs) ->
      element.bind 'click', (event) ->
        scope.$emit('actions.running')
        scope.$eval(attrs.actionCall).then ->
          scope.$emit('actions.finished')

.directive 'details', ->
  restrict: 'E'
  require: '^slugItem'
  template: """<div class="slug-item-details" ng-transclude></div>"""
  replace: true
  transclude: true

.directive 'detail', ->
  restrict: 'EA'
  template: """<span class="detail" ng-transclude></span>"""
  replace: true
  transclude: true

.directive 'content', ->
  restrict: 'E'
  require: '^slugItem'
  template:
    """<div class="slug-item-content" collapse="!isOpen" ng-transclude></div>"""
  replace: true
  transclude: true
