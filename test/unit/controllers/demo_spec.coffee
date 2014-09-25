describe 'DemoService', ->
  beforeEach module('slug.services.demo')

  it 'creates new service', inject (DemoService, Service) ->
    spyOn(Service, 'save').and.callFake (service) ->
      myDemo = { endpoint: 'https://api.github.com', key: 'github', name: 'GitHub', description: 'fancy desc' }
      DemoService.create(myDemo)

      expect(Service.save).toHaveBeenCalled()

      expect(service.endpoints).toEqual([{code: 'github', url: 'https://api.github.com'}])
      expect(service.name).toEqual('GitHub API')
      expect(service.description).toEqual('fancy desc')
      expect(service.demo).toEqual('github')

describe 'DemoCall', ->
  beforeEach module('slug.services.demo')

  [$httpBackend] = []

  beforeEach inject (_$httpBackend_) ->
    $httpBackend = _$httpBackend_

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  it 'calls http api', inject (DemoCall) ->
    example = { method: 'GET', url: 'example'}
    service = { _id: 3 }
    $httpBackend.expect('GET', '/api/services/3/call?method=GET&url=example').respond('')
    DemoCall.perform(service, example)
    $httpBackend.flush()

describe 'DemoCallCtrl', ->
  beforeEach module('slug.services.demo')

  [scope, ctrl] = []

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    ctrl = $controller 'DemoCallCtrl', $scope: scope

  it 'performs http call', inject (DemoCall) ->
    expect(scope.perform).toBeDefined()

    scope.call = 'sample'
    scope.service = {_id: 3}

    spyOn(DemoCall, 'perform').and.callThrough()
    scope.perform()
    expect(DemoCall.perform).toHaveBeenCalledWith(scope.service, scope.call)


