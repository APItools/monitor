describe 'PipelineCtrl', ->
  beforeEach module('slug.middlewares')

  [scope, ctrl, $httpBackend, stateParams] = []

  beforeEach inject (_$httpBackend_, $rootScope, $controller, Pipeline) ->
    $httpBackend = _$httpBackend_
    pipeline = new Pipeline(service_id: 1, middlewares: {})

    scope = $rootScope.$new()
    stateParams = serviceId: 1, middlewareIndex: 0
    ctrl = $controller 'PipelineCtrl', $scope: scope, $stateParams: stateParams, pipeline: pipeline

  it 'assigns pipeline', ->
    expect(scope.pipeline).toBeDefined()

  it 'gets service info from the backend', ->
    expect(scope.pipeline).toEqualData(service_id: stateParams.serviceId, middlewares: {})

  it 'saves the pipeline', ->
    spyOn(scope, 'updatePipeline').and.callThrough()
    spyOn(scope, 'revertPipeline')
    spyOn(scope.middlewares, 'ready').and.callFake (callback) -> callback()

    scope.savePipeline()

    expect(scope.updatePipeline).toHaveBeenCalled()
    expect(scope.revertPipeline).not.toHaveBeenCalled()

    $httpBackend
      .expectPOST('/api/services/1/pipeline').respond({})

    $httpBackend.flush()

    expect(scope.revertPipeline).toHaveBeenCalled()
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();

  it 'updates the pipeline', ->
    scope.middlewares.array.push name: 'req', uuid: 'fake'
    scope.middlewares.array.push name: 'res', uuid: 'monk'

    scope.updatePipeline()

    updated = {
      fake: {name: 'req', uuid: 'fake', position: 0 }
      monk: {name: 'res', uuid: 'monk', position: 1 }
    }
    expect(scope.pipeline.middlewares).toEqualData(updated)
