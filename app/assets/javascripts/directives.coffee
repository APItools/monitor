angular.module('slug.directives', [
  'slug.directives.pretty_print'
  'slug.directives.list'
  'slug.directives.confirm'
  'slug.directives.token_input'
  'slug.directives.navigation'
  'slug.directives.demo_block'
  'slug.directives.split_panes'
  'slug.service_submenu'
])

.directive 'apitools', ($http, $q) ->
    restrict: 'EA'
    scope: {}
    compile: (element, attrs, transclude) ->
      name = $q.defer()
      http = $http.get('/api/get_slug_name')
      http.then (response) ->
        name.resolve(response.data.slug_name)

      return (scope, element, attrs) ->
        scope.name = name

.directive 'relHref', ($location) ->
    link: (scope, element, attrs) ->
      href = "." + $location.path() + attrs.relHref
      element.attr('href', href).attr('target', '_self')

.directive 'preventDisabled', ->
    link: (scope, element, attrs) ->
      element.on(attrs.preventDisabled, -> false)

.directive 'zeroclipboard', ->
  link: (scope, element, attrs) ->
    button = angular.element(
      '<button class="btn copy-to-clipboard">
      <i class="icon-copy"></i></button>'
    )
    element.after(button)

    clip = new ZeroClipboard(button)
    clip.on 'dataRequested', -> clip.setText($(this).prev().text())

.directive 'focus', ->
  link: (scope, element, attrs) ->
    return unless element.is('input')

    giveFocus = (visible) -> element.focus() if visible
    isVisible = -> element.is(':visible')

    scope.$watch(isVisible, giveFocus)

.directive 'fillHeight', ($window, $timeout) ->
  TRANSITION_END = 'webkitTransitionEnd oTransitionEnd transitionend msTransitionEnd'
  window = angular.element($window)

  link: (scope, element, attributes) ->
    body = element.closest('.modal-body')
    parent = element.closest(attributes.fillHeight)

    window.on 'resize.fillHeight', ->
      scope.$apply()

    element.closest('.modal').on TRANSITION_END, -> scope.$apply()

    total = -> body.height()

    top = ->
      parent.position().top

    size = ->
      total() - top()

    scope.$on 'destroy', ->
      window.unbind('resize.fillHeight')

    scope.$watch size, (size) ->
      element.css('height', size)


.directive 'author', ->
  restrict: 'E'
  scope:
    name: '='
    github: '='

  link: (scope, element, attributes) ->

    name = scope.name
    github = scope.github

    unless name
      element.text('unknown')
      return

    link = angular.element('<a/>')

    if github
      link.attr(title: name)
      link.attr(href: "//github.com/" + github)
      link.text("@" + github)
    else
      link.text(name)

    element.html(link)

.directive 'truncate', ($interpolate, $compile) ->
  restrict: 'A'
  scope: true
  link: (scope, element, attributes) ->
    template =
      """<span class="truncated">{{ truncated }}
          <span class="dots" ng-show="rest.length > 0">&hellip;</span>
          <span class="rest">{{ rest }}</span>
      </span>"""
    expression = element.text()
    interpolate = $interpolate(expression)
    length = attributes.truncate
    element.html(template)

    scope.$watch interpolate, (text) ->
      text = String(text)

      scope.truncated = text.substring(0, length)
      scope.rest = text.substring(length)

      $compile(element.contents())(scope)

.directive 'draggable', ->
  restrict: 'CA'
  compile: (element, attrs) ->
    element.draggable()
    (scope, element, attrs) ->
      config = attrs.draggable
      scope.$watch config, (options) ->
        element.draggable(options)

.directive 'logLevel', ->
  scope:
    logLevel: '='
  link: (scope, element, attrs) ->
    level = scope.logLevel
    element.text(level)
    element.addClass("label-#{level}")


## Monkey patches for tabs directive

.directive 'tabContentTransclude', ->
  link: (scope, element, attrs, ctrl) ->
    updateInvalid = (invalid) -> scope.tab.invalid = invalid > 0
    # can't use :invalid pseudo selector
    # as it is not applied directly after change
    invalidCount = ->
      # using jquery element.find with or selector triggers repaint in browser
      element[0].querySelectorAll('input.ng-invalid,select.ng-invalid').length

    scope.$watch(invalidCount, updateInvalid)
    # element.on 'change', 'select', -> updateInvalid(invalidCount())

.directive 'tabHeadingTransclude', ->
  link: (scope, elm, attrs, ctrl) ->
    invalid = -> scope.invalid
    scope.$watch invalid, (isInvalid) ->
      elm.parent().toggleClass('invalid', isInvalid)

.directive 'rel', ->
    restrict: 'A'
    compile: (element, attrs) ->
      element.attr('target', '_blank') if attrs.rel == 'external'

.factory 'animationFrame', ($window) ->
  requestAnimationFrame =
    $window.requestAnimationFrame ||
    $window.mozRequestAnimationFrame ||
    $window.webkitRequestAnimationFrame ||
    $window.oRequestAnimationFrame ||
    $window.msRequestAnimationFrame

  cancelRequestAnimationFrame =
    $window.cancelRequestAnimationFrame ||
    $window.mozCancelRequestAnimationFrame ||
    $window.webkitCancelRequestAnimationFrame ||
    $window.oCancelRequestAnimationFrame ||
    $window.msCancelRequestAnimationFrame

  request: (fun) -> requestAnimationFrame(fun)
  cancel: (id) -> cancelRequestAnimationFrame(id)
  withFallback: (func) -> requestAnimationFrame?(func) || func()

.factory 'defer', ($browser, animationFrame) ->
  (fun) -> $browser.defer -> animationFrame.request(fun)
