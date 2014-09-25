describe 'MiddlewareEditCtrl', ->
  beforeEach module('slug.middlewares')

  [scope, ctrl, stateParams] = []

  beforeEach inject ($rootScope, $controller, TemporaryChanges, $modal) ->
    scope = $rootScope.$new()
    scope.temporary_changes = new TemporaryChanges()
    scope.middlewares = jasmine.createSpyObj('Middlewares', ['get', 'replace'])

    ctrl = ->
      $controller 'MiddlewareEditCtrl', $scope: scope, $modal: $modal, service: null

  it 'opens the dialog with right options', inject ($modal, $q) ->

    modal = $modal.open(template: "<p/>")

    spyOn($modal, 'open').and.callFake (dialogOptions) ->
      expect(dialogOptions.templateUrl).toBe('/middlewares/edit.html')
      expect(dialogOptions.controller).toBe('MiddlewareFormCtrl')
      expect(dialogOptions.resolve.middleware).toBeDefined()
      expect(dialogOptions.resolve.changes).toBeDefined()
      expect(dialogOptions.resolve.save).toBeDefined()

      modal

    ctrl()

  it 'calls close after closing the dialog', inject ($q, $modal) ->
    modal = $modal.open(template: "<p/>")
    spyOn(modal.result, 'then')
    spyOn($modal, 'open').and.returnValue(modal)
    ctrl()
    expect(modal.result.then).toHaveBeenCalledWith(scope.close)

  it 'has close function', ->
    ctrl()
    expect(scope.close).toBeDefined()
    expect(scope.close).toEqual(jasmine.any(Function))

  # TODO: test the close function

  it 'removes the middleware when save called without middleware', ->
    ctrl()

    original = {}
    scope.middlewares.get.and.returnValue(original)

    scope.save('some-uuid')
    expect(scope.middlewares.replace).toHaveBeenCalledWith(original, undefined)

  it 'replaces the middleware on save', ->

    ctrl()

    original = { original: true }
    another = { another: true }

    scope.middlewares.get.and.returnValue(original)

    scope.save('some-uuid', another)
    expect(scope.middlewares.get).toHaveBeenCalledWith('some-uuid')
    expect(scope.middlewares.replace).toHaveBeenCalledWith(original, another)

describe 'MiddlewareEditCtrl', ->
  beforeEach module('slug.middlewares')

  [scope, save, middleware] = []

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()

    middleware = { uuid: 'uuid' }
    save = jasmine.createSpy('save')
    scope.$close = jasmine.createSpy('close')

    $controller 'MiddlewareFormCtrl', $scope: scope, save: save, middleware: middleware, savePipeline: null, changes: null

  it 'deletes middleware', ->
    scope.delete()
    expect(save).toHaveBeenCalledWith('uuid')

  it 'saves middleware', ->
    scope.save()
    expect(save).toHaveBeenCalledWith('uuid', middleware)
