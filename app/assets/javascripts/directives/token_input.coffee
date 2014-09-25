angular.module('slug.directives.token_input', ['slug.directives'])

.factory 'KEY_CODES', ->
  LEFT_ARROW: 37
  RIGHT_ARROW: 39
  ENTER: 13
  BACKSPACE: 8
  DELETE: 46

.factory 'TokenCollection', ->
  class TokenCollection
    constructor: (@tokens) ->

    has: (token) ->
      string = token.toString()
      for existing in @tokens
        return existing if existing.toString() == string
      return false

.factory 'TokenFormat', ->
  AVAILABLE_OPERATORS = ['>=', '>', '<', '<=', '=', '=']

  ops = AVAILABLE_OPERATORS.join('|')
  key = '[^\\s\=\>\<]+'

  new RegExp("(#{key})\\s*(#{ops})\\s*(#{key})")

.factory 'Token', (TokenFormat) ->
  class Token
    constructor: (attributes = {}) ->
      angular.extend(this, attributes)
      delete @new_token
    pattern: TokenFormat.source
    toString: ->
      [@key, @op, @value].join(' ')

.factory 'NewToken', (Token, TokenFormat) ->
  class NewToken extends Token

    constructor: (attributes = {}) ->
      @new_token = true
      super(attributes)

    parse: =>
      match = @input?.match(TokenFormat)

      if match
        [_, key, op, value] = match

        token = new Token(key: key, op: op, value: value)

        return token
      else
        console.warn("#{@input} does not match #{@pattern}")
        return

    reset: =>
      @input = null

.controller 'TokenSuggestionsController', ($scope, Token) ->
  $scope.removeToken = (token) ->
    $scope.suggestions = _($scope.suggestions).without(token)

  $scope.toggleToken = (token) ->
    token.active = true
    $scope.tokens.push(token)
    $scope.removeToken(token)

.controller 'TokenInputController', ($scope, NewToken, Token, flash) ->
  $scope.tokens ||= []

  $scope.new_token = new NewToken()

  $scope.addToken = (new_token) ->
    if token = new_token.parse()
      $scope.tokens.push(token)
      token.active = true
      new_token.reset()
    else
      flash.warning = "#{new_token.input} is not valid filter syntax"

  $scope.selectPrev = ->
    index = if $scope.selected? then $scope.selected else $scope.tokens.length
    index = if index > 0 then index - 1 else 0
    $scope.select(index)

  $scope.selectNext = ->
    index = $scope.selected
    index = if index? then index + 1 else $scope.tokens.length
    $scope.select(index)

  $scope.select = (index) ->
    max = $scope.tokens.length
    index = if index > max then max else index
    index = if index < 0 then 0 else index
    $scope.selected = index

  $scope.removeToken = (token) ->
    $scope.tokens = _($scope.tokens).without(token)
    # TODO: handle $scope.selected

  $scope.toggleToken = (token) ->
    token.active = !token.active

  $scope.delete = ->
    selected = $scope.tokens[$scope.selected]
    $scope.removeToken(selected)
    !!selected

  $scope.edit = (token) ->
    if previous = $scope.editing
      # discarding the changes
      previous

    index = $scope.tokens.indexOf(token)
    $scope.editing =
      if index? and token
        index: index
        token: token
        value: token.toString()
      else
        null

  $scope.updateToken = (token) ->
    new_token = new NewToken(input: $scope.editing.value)

    if update = new_token.parse()
      angular.extend(token, update)
      $scope.editing = null

.directive 'tokenInput', ->
  restrict: 'E'
  replace: true
  transclude: true
  controller: 'TokenInputController'
  scope:
    tokens: '=tokens'
  template:
    """
    <ul class="token-active">
      <token ng-repeat="token in tokens"></token>
      <new-token></new-token>
      <a class="help" tooltip="Required format is: name = value">
        <i class="icon-help"></i>
      </a>
    </ul>
    """

  link: (scope, element, attrs) ->
    scope

.directive 'tokenSuggestions', (TokenCollection) ->
  restrict: 'E'
  scope:
    tokens: '=tokens'
    suggestions: '=suggestions'
  controller: 'TokenSuggestionsController'
  replace: true
  transclude: true
  template:
    """
    <ul class="token-suggestions"
      ng-class="{empty: suggestions && unique_suggestions.length == 0 }">
      <token ng-repeat="token in suggestions"></token>
      <li class="no-suggestions">
        We don't have any more filter suggestions.
      </li>
    </ul>
    """
  link: (scope, element, attrs) ->
    element.addClass('suggestions')

    scope.$watch 'suggestions', (suggestions) ->
      tokens = new TokenCollection(scope.tokens)
      scope.unique_suggestions = _(suggestions).filter (suggestion) ->
        not suggestion.disabled = tokens.has(suggestion)

    element.on 'click', '.show-mode', (event) ->
      token = $(event.target).scope().$eval('token')
      return false if token.disabled
      scope.toggleToken(token)

.directive 'token', (KEY_CODES, debug) ->
  restrict: 'E'
  #require: '^tokenInput'
  replace: true
  transclude: true
  template:
    """
    <li class="token"
        ng-class="{selected: $index === selected,
          suggested: token.suggestion, active: token.active,
          editing: $index === editing.index, disabled: token.disabled}">
      <a href class="toggle"
        ng-click="toggleToken(token)">
        <i class="icon" ng-class="{'icon-check': token.active,
          'icon-check-empty': !token.active }">
        </i>
      </a>
      <span class="show-mode" ng-click="edit(token)"
        ng-show="$index !== editing.index">
        <span class="token-key">{{ token.key }}</span>
        <span class="token-operator">{{ token.op }}</span>
        <span class="token-value">{{ token.value }}</span>
      </span>
      <form class="edit-mode" ng-submit='updateToken(token)'
        ng-if="$index === editing.index" class="token-edit">
        <input type="text" pattern='{{ token.pattern }}'
          ng-model="editing.value" autosize>
      </form>

      <a href class="delete" ng-click="removeToken(token)">
        <i class="icon icon-trash"></i>
      </a>
    </li>
    """
  link: (scope, element, attrs) ->
    element.on 'keyup', 'input', (event) ->
      switch(event.keyCode)
        when KEY_CODES.ENTER
          debug -> console.log("ENTER pressed, event: %O", event.keyCode, event)


      return false

.directive 'autosize', () ->
  restrict: 'A'
  require: 'ngModel'
  priority: 1000
  link: (scope, element, attrs, ngModel) ->
    FREE_SPACE = 16
    return unless element.is('input')

    $shadow = angular.element('<span/>').css(
      font: element.css('font'),
      position: 'absolute',
      visibility: 'hidden',
      zIndex: -1,
      whiteSpace: 'pre'
    )
    $shadow.insertAfter(element)

    scope.$on '$destroy', -> $shadow.remove()

    element.on 'keyup focus focusin blur resize', (event) ->
      $shadow.text(ngModel.$viewValue)
      element.width($shadow.width() + FREE_SPACE)

.directive 'newToken', (KEY_CODES, debug) ->
  restrict: 'E'
  #require: '^tokenInput'
  scope: true
  replace: true
  template:
    """
    <li class="token new">
      <form class="edit-mode show-mode" nam="form" ng-submit="addToken(token)">
        <input placeholder="New filter" type="text" autosize
          pattern='{{ token.pattern }}' required ng-model="token.input" />
        <button class="save-token btn-link">
          <i class="icon icon-plus"></i>
        </button>
      </form>
    </li>
    """
  link: (scope, element, attrs) ->
    $el = $(element)
    scope.token = scope.new_token

    handleToken = (code) ->
      switch(code)
        when KEY_CODES.ENTER
          scope.addToken(scope.token)
          #michal, just added this to pseudo solve the issue when
          # you add a long token, then add new got same width...
          element.children().children().css(width: "auto")
        else
          scope.select(null)

    handleEmptyToken = (code) ->
      switch(code)
        when KEY_CODES.LEFT_ARROW
          scope.selectPrev()
        when KEY_CODES.RIGHT_ARROW
          scope.selectNext()
        when KEY_CODES.DELETE
          scope.delete()
        when KEY_CODES.BACKSPACE
          if scope.delete()
            scope.selectPrev()
        when KEY_CODES.ENTER
          scope.$emit('search')
        else
          scope.select(null)
          debug -> console.log('keycode', event.keyCode)

    $el.on 'focusin', (event) ->
      scope.$apply -> scope.edit(null)

    $el.on 'keydown', (event) ->
      code = event.keyCode
      length = event.target.value?.length > 0

      switch code
        when KEY_CODES.ENTER
          return false unless length > 0

    $el.on 'keyup', (event) ->
      code = event.keyCode

      scope.$apply ->
        if(event.target.value?.length > 0)
          handleToken(code)
        else
          handleEmptyToken(code)



