describe 'NotificationsListCtrl', ->
  beforeEach module('slug.notifications')

  [scope, Search] = []

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new()
    ctrl = $controller 'NotificationsListCtrl', $scope: scope

  it 'should wipe notifications when scope.wipe is called', inject (Event) ->
    spyOn(Event, "wipe").and.callFake (callback) -> callback()
    scope.search = jasmine.createSpyObj('Search', ['do'])

    scope.wipe()

    expect(Event.wipe).toHaveBeenCalled()
    expect(scope.search.do).toHaveBeenCalledWith()
