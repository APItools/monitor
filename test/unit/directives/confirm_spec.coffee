describe 'confirm directive', ->
  [element, $scope, confirmation, original] = []

  beforeEach module('slug.directives.confirm')

  beforeEach inject ($rootScope, $compile) ->
    element = angular.element('<a class="btn" slug-confirm ng-click="action()">link</a>')

    $scope = $rootScope.$new()
    $scope.action = ->

    $compile(element)($scope)

    $scope.$digest()

    confirmation = element.find('.slug-confirmation')
    original = element.find('.slug-confirm-original')

  it 'should have a confirm class', ->
    expect(element).toHaveClass('slug-confirm')

  it 'should add a confirmation to the element', ->
    expect(confirmation.length).toBe(1)
    expect(confirmation.text()).toBe('Yes')

  it 'should show confirmation when clicked', ->
    expect(element).not.toHaveClass('slug-confirm-active')
    element.click()
    expect(element).toHaveClass('slug-confirm-active')

  it 'should prevent original action when first clicked', ->
    spyOn($scope, 'action')
    element.click()
    expect($scope.action).not.toHaveBeenCalled()

  it 'should call original action when confirmation was clicked', ->
    spyOn($scope, 'action')
    confirmation.click()
    expect($scope.action).toHaveBeenCalled()

  it 'should toggle active-hidden classes on focus out', ->
    element.click()
    expect(element).toHaveClass('slug-confirm-active')
    confirmation.focusout()
    expect(element).not.toHaveClass('slug-confirm-active')

  it 'wraps original content', ->
    expect(element).toContainElement('.slug-confirm-original')
    expect(original).toContainHtml('link')

  it 'ends up with right classes after click and mouseleave', ->
    element.click()
    confirmation.click()
    confirmation.mouseleave()

    expect(element).not.toHaveClass('slug-confirm-active')
