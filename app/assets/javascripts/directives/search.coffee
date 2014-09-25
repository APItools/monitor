angular.module('slug.directives.search', [])
.controller 'SearchBoxCtrl', ($scope, flash) ->
  tokens = $scope.search.tokens
  $scope.search.type = "basic"

  $scope.saveFilter = ->
    filter = $scope.search.using_filter
    filter.tokens = tokens()
    filter.$save ->
      flash.success = "Filter saved"

  $scope.saveFilterAs = ->
    filter = $scope.newFilter(tokens())
    filter.$save ->
      flash.success = "Filter created"
      $scope.filters.push(filter)
      $scope.search.used_filter = filter
      $scope.$emit('editFilter', filter)

.directive 'searchLoading', ->
  template:
    """<button id="search-loading"
        class="btn btn-block btn-large btn-primary loading">
        <i class="icon-refresh icon-spin"></i> Loading...
      </button>"""
  link: (scope, element, attributes) ->
    loading = attributes.searchLoading || 'search.loading'
    scope.$watch loading, (loading) -> element.toggle(!!loading)

.directive 'searchLoadMore', ->
  template:
    """<button ng-click="search.more()"
        class="btn btn-block btn-large btn-primary">
        <span ng-transclude></span>
      </button>"""
  transclude: true
  link: (scope, element, _attributes) ->
    expression = -> scope.search.canLoadMore()
    callback = (canLoadMore) -> element.toggle(!!canLoadMore)
    scope.$watch(expression, callback)

.directive 'searchBox', ->
  templateUrl: '/search/search_box.html'
  controller: 'SearchBoxCtrl'
  replace: true
  restrict: 'EA'

.controller 'ControlBoxCtrl', ($scope, TokenHeuristics) ->
  $scope.selected = []

  $scope.toggleAllItems = ->
    if $scope.selected.length == 0
      $scope.selected = $scope.search.results
    else
      $scope.deselect()

  $scope.hasSelected = ->
    $scope.selected.length > 0

  $scope.deselect = (items) ->
    if items?
      $scope.selected = _($scope.selected).without(items...)
    else
      $scope.selected = []

  $scope.highlightItems = (items) ->
    starred = _(items).any (item) -> item.starred
    toggle = if starred then '$unstar' else '$star'
    item[toggle]() for item in items
    $scope.deselect()

  $scope.filterItems = (items) ->
    heuristics = new TokenHeuristics(items)
    heuristics.singular(
      'level', 'channel', 'req.method', 'res.status', 'req.host', 'req.uri'
    )
    $scope.suggestions = heuristics.suggestions()
    $scope.deselect()

  $scope.trashItems = (items) ->
    for item in items
      item.$delete (item) -> $scope.search.remove(item)
    $scope.deselect(items)

  $scope.toggleItem = (item) ->
    return unless item
    if $scope.selected.indexOf(item) >= 0 # is already selected
      $scope.selected = _($scope.selected).without(item)
    else
      $scope.selected.push(item)

.directive 'controlBox', ->
  templateUrl: '/search/control_box.html'
  controller: 'ControlBoxCtrl'
  replace: true
  restrict: 'EA'

.directive 'loadMore', ->
  restrict: 'E'
  replace: true
  transclude: true
  template: """
    <div class="btn-toolbar">
      <button id="load-more" ng-show="search.has_more > 0"
        ng-click="search.refresh()" class="btn btn-block btn-large btn-primary">
        <i class="icon-refresh"></i> <span ng-transclude/>
      </button>
     </div>"""

.directive 'toggleItem', ->
  replace: true
  template:
    """<input type="checkbox" class="toggle-item" ng-model="checked"
      ng-change="toggleItem(item)" />
    """
  scope: true
  link: (scope, element, attributes) ->
    scope.$watch 'selected.indexOf(item) >= 0', (selected) ->
      scope.checked = selected
      element.addClass('slug-item-check')

    scope.$watch attributes.toggleItem, (item) ->
      scope.item = item

.directive 'toggleAllItems', ->
  replace: true
  template: """
            <input type="checkbox" class="toggle-all-items"
              tooltip="Select/Deselect All" />
            """
  link: (scope, element, attributes) ->
    input = element.filter('input')

    areSame = ->
      scope.selected == scope.search.results

    input.bind 'click', ->
      scope.toggleAllItems()
      input.prop('checked', areSame())

    scope.$watch areSame, (same) ->
      input.prop('checked', same)
