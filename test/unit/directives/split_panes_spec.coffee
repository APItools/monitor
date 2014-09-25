describe 'split panes directive', ->
  [$compile, $rootScope] = []

  beforeEach module('slug.directives.split_panes')

  beforeEach inject (_$rootScope_, _$compile_) ->
    $rootScope = _$rootScope_
    $compile = _$compile_

  it 'splits pane with two elements', ->
    element = $compile('<div split-panes="horizontal"><div>first</div><div>second</div></div>')($rootScope)
    expect(element.find('.split-pane')).toHaveLength(2)
    expect(element).toContainElement('.split-panes-handle')

  it 'throws error when splitting other than two elements', ->
    expect(-> $compile('<div split-panes="vertical"></div>')($rootScope)).
      toThrowError('split panes can split just two elements')

  it 'throws error when splitting without orientation', ->
    expect(-> $compile('<div split-panes></div>')($rootScope)).
      toThrowError('split panes needs orientation vertical or horizontal')

