describe 'pretty print directive', ->
  template = null
  $scope = null

  beforeEach module('slug.directives.pretty_print')

  beforeEach inject ($rootScope, $compile) ->
    $scope = $rootScope.$new()

    template = (template) ->
      element = angular.element("<div>#{template}</div>")
      element = $compile(element)($scope)

      $scope.$digest()

      element

  it 'should be transformed to <pre>', ->
    pre = template('<pretty-print/>').children('pre')

    expect(pre.length).toBe(1)

  it 'should set default theme', ->
    pre = template('<pretty-print/>').find('pre')

    expect(pre.hasClass('cm-s-default'))

  it 'should set different theme', ->
    pre = template('<pretty-print theme="night"/>').find('pre')

    expect(pre.hasClass('cm-s-night'))
    expect(pre.hasClass('cm-s-default')).toBe(false)

  it 'should set highlighted code', ->
    $scope.code = code = '{"key": false}'
    pre = template('<pretty-print value="code"/>').find('pre')

    expect(pre.html()).toBe(code)

  it 'should pretty print json code', ->
    $scope.code = '{"key": true}'
    highlighted = '<span class="cm-string">"{\\"key\\": true}"</span>'
    pre = template('<pretty-print value="code" lang="json" />').find('pre')

    expect(pre.html()).toBe(highlighted)

  it 'should wait if object has $promise', inject ($q) ->
    deferred = $q.defer()
    promise = deferred.promise

    $scope.code = { $promise: promise }

    highlighted = '<span class="cm-string">"test"</span>'
    pre = template('<pretty-print value="code" lang="json"/>').find('pre')

    expect(pre.html()).toBe('')

    $scope.$apply ->
      deferred.resolve('test')

    expect(pre.html()).toBe(highlighted)

  it 'should update code if object is changed', ->
    pre = template('<pretty-print value="code" lang="json"/>').find('pre')

    expect(pre.html()).toBe('')

    $scope.$apply ->
      $scope.code = 'TEST'

    highlighted = '<span class="cm-string">"TEST"</span>'

    expect(pre.html()).toBe(highlighted)
