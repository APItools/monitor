angular.module('slug.directives.split_panes', [])

.directive 'splitPanes', ->

  scope:
    orientation: '@splitPanes'

  controller: ($scope) ->
    @orientation = switch $scope.orientation
      when 'vertical' then 'height'
      when 'horizontal' then 'width'
      else throw new Error('split panes needs orientation vertical or horizontal')

  link: (scope, element, attributes, controller) ->
    panes = element.children()
    orientation = controller.orientation
    Orientation = orientation.charAt(0).toUpperCase() + orientation.slice(1)

    unless panes.length == 2
      throw new Error('split panes can split just two elements')

    panes.addClass("split-pane")
    element.addClass("split-panes split-pane-#{orientation}")

    [first, last] = panes
    handle = angular.element("<div class='split-panes-handle split-panes-handle-#{orientation}'></div>")

    first = angular.element(first).
      addClass('split-pane-first').
      after(handle)

    last = angular.element(last).
      addClass('split-pane-last')

    update = switch orientation
      when 'height' then ['bottom', 'top', 'clientY']
      when 'width' then ['right', 'left', 'clientX']

    resize = (event) ->
      bounds = element[0].getBoundingClientRect()

      [x,y,axis] = update
      available = bounds[x] - bounds[y]

      available -= last["outer#{Orientation}"]() - last[orientation]()
      pos = event[axis] - bounds[y]

      pos = if pos > available then available else pos

      first.css((_css = {}; _css[orientation] = "#{pos}px"; _css))
      last.css((_css = {}; _css[orientation] = "#{available - pos}px"; _css))

      scope.$emit('resize')
      return true

    resize = _.debounce(resize, 10)

    handle.on 'mousedown touchstart', (event) ->
      event.preventDefault()
      event.stopPropagation()

      element.on('mousemove touchmove', resize)
      return false

    element.on 'mouseup touchend', ->
      element.off('mousemove touchmove', resize)

.directive 'paneMaxSize', ->
  require: '^splitPanes'
  link: (scope, element, attrs, splitPanes) ->
    # I cannot express how unhappy I'm with this, but man gotta do what man gotta do.
    # If require: '^name' would look JUST in parents (excluding current element) it would work
    # out of the box. But becasue it includes current element and one element can be both split pane
    # and have min/max but for upper pane.
    controller = element.parent().inheritedData('$splitPanesController') || splitPanes
    limit = {}
    limit["max-#{controller.orientation}"] = attrs.paneMaxSize
    element.css(limit)

.directive 'paneMinSize', ->
  require: '^splitPanes'
  link: (scope, element, attrs, splitPanes) ->
    controller = element.parent().inheritedData('$splitPanesController') || splitPanes
    limit = {}
    limit["min-#{controller.orientation}"] = attrs.paneMinSize
    element.css(limit)

.directive 'paneSetHeight', ($window, $timeout) ->
  link: (scope, element) ->
    parent = element.parent()

    alive = true
    update_size = ->
      return unless alive
      element.hide()
      newHeight =  parent.height() - 1 # making sure it won't get bigger than it's parent
      element.css('height', newHeight + "px")
      element.show()


    scope.$watch 'loading', update_size
    window = angular.element($window)
    window.on('resize', update_size)
    scope.$on('$destroy', -> alive = false; window.off('resize', update_size))
    for time in [200..900] by 100
      $timeout(update_size, time)
