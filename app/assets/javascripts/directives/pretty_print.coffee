pretty_print = angular.module('slug.directives.pretty_print', [])

pretty_print.directive 'prettyPrint', ($sce) ->
  restrict: 'E',
  template: '<pre ng-bind-html="prettyPrintCode"/>',
  replace: true,
  scope:
    object: '=value'
    theme: '@theme'
    language: '@lang'


  link: (scope, element, attrs) ->
    binding = -> scope.object

    theme = scope.theme || 'default'

    element.addClass("cm-s-#{theme}")

    update = (object) ->
      return unless object

      switch scope.language
        when 'json'
          text = angular.toJson(object, true)
          lang = name: 'javascript', json: true
        else
          text = object

      scope.prettyPrintCode = $sce.trustAsHtml(syntax_highlight(text, lang))

    object = scope.$eval(binding)

    if callback = object?.$promise?.then
      callback(update)
    else
      scope.$watch(binding, update)

# available languages: http://codemirror.net/mode/meta.js
# defaults to plain text ('null' mode)
syntax_highlight = (text, language = 'null') ->
  return unless text

  node = document.createElement('div')
  # runMode is documented @ http://codemirror.net/demo/runmode.html
  CodeMirror.runMode(text, language, node)
  node.innerHTML
