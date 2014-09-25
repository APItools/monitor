angular.module('slug.directives.highlight', [])

.directive 'highlight', ($browser, animationFrame) ->
  DEFAULT_THEME = 'default'

  scope:
    code: "=highlight"
    contentType: "=?highlightContentType"
    transform: "@highlightTransform"
    theme: "@highlightTheme"

  link: (scope, element, attrs) ->
    output = element.get(0)

    theme = scope.theme || DEFAULT_THEME
    element.addClass("cm-s-" + theme)

    transform = (code) ->
      switch scope.transform
        when 'json'
          scope.contentType = 'application/json'
          angular.toJson(code, true)
        else
          code

    update = ->
      $browser.defer ->
        code = transform(scope.code)

        animationFrame.withFallback ->
          CodeMirror.runMode(code, scope.contentType, output)

    binding = -> scope.code
    scope.$watch(binding, update, !!attrs.highlightRefresh)
