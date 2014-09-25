describe 'HomeCtrl', ->
  beforeEach module('slug.home')

  [scope, ctrl] = []

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    ctrl = $controller 'HomeCtrl', $scope: scope, services: []

  it 'assigns demo apis', inject () ->
    expect(scope.demos).toBeDefined()
    expect(scope.demos.github).toBeDefined()

describe 'HomeDemoCtrl', ->
  beforeEach module('slug.home')

  [scope, ctrl] = []

  beforeEach inject ($rootScope, $controller) ->

    scope = $rootScope.$new()
    scope.services = []

    ctrl = -> $controller 'HomeDemoCtrl', $scope: scope

  it 'creates demo service', inject (DemoService) ->
    ctrl()

    scope.demo = 'whatever'

    spyOn(DemoService, 'create')
    scope.createDemo()
    expect(DemoService.create).toHaveBeenCalledWith('whatever', jasmine.any(Function))


  it 'finds service for the demo', ->
    ctrl()
    expect(scope.service).not.toBeDefined()

    github = {demo: 'github'}
    scope.services = [github]
    scope.key = 'github'

    ctrl()
    expect(scope.service).toBeDefined()
    expect(scope.service).toBe(github)
