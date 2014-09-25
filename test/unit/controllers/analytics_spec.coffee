describe 'AnalyticsCtrl', ->
  beforeEach module('slug.controllers')

  [scope, ctrl, $httpBackend] = []

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    $httpBackend = _$httpBackend_

    scope = $rootScope.$new()
    ctrl = $controller 'AnalyticsCtrl', $scope: scope

  # TODO: enable & fix this one
  xit 'updating analytics', ->
    scope.doCustomLastHour()

    response =
      results: [
        {metric: 'A', data: [0, 1, 2] }
      ],
      normalized_query:
        range:
          start: 1372322287
          end: 1372408687
          granularity: 60

    $httpBackend.expectGET(/^\/api\/stats\?query=/).respond(response)
    $httpBackend.flush()

    first = scope.template

    scope.doCustomLastDay()

    $httpBackend.expectGET(/^\/api\/stats\?query=/).respond(response)
    $httpBackend.flush()

    expect(first).not.toBe(scope.template)
