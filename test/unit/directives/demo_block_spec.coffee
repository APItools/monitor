describe 'demo block directive', ->
  [element, $scope] = []

  beforeEach module('slug.directives.demo_block')

  beforeEach inject ($rootScope, $compile, $httpBackend) ->
    element = angular.element('<div demo-block="spec">{{service}}</div>')

    $scope = $rootScope.$new()

    $compile(element)($scope)
    $httpBackend.expectGET("/api/config").respond({})

    $scope.$digest()

  it 'should add a button to close it', ->
    expect(element).toContainElement("button.demo-block-remove")

