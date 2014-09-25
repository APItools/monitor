angular.module('slug.directives.filter', ['slug.directives'])
.controller 'NavigationFilterCtrl', ($scope, flash) ->
  $scope.canEdit = (filter) ->
    filter && !filter.builtin # && $scope.search.using_filter == filter

  $scope.canDelete = (filter) ->
    $scope.canEdit(filter) && !!filter._id

  $scope.isEditing = (filter) ->
    $scope.editing?.$filter == filter

  $scope.edit = (filter) ->
    $scope.editing = angular.copy(filter)
    $scope.editing?.$filter = filter

  $scope.update = (filter) ->
    filter.$save ->
      flash.success = 'Filter saved'
      $scope.editing = null

  $scope.apply = (filter) ->
    $scope.edit(null)
    $scope.search.use(filter)

  $scope.delete = (filter) ->
    filter.$delete ->
      flash.info = "Filter removed"
      $scope.remove(filter)

  $scope.remove = (filter) ->
    $scope.filters = _($scope.filters).without(filter)

  $scope.clear = ->
    $scope.edit(null)
    $scope.search.clear()

  $scope.off = (filter) ->
    $scope.search.clear()

  $scope.save = (filter) ->
    copy = angular.copy($scope.editing)
    angular.extend(filter, copy)
    filter.$save ->
      flash.info = "Filter saved"
      $scope.edit(null)
      $scope.apply(filter)

  $scope.abort = (filter) ->
    $scope.remove(filter) if !filter._id
    $scope.edit(null)

  $scope.addNew = () ->
    filter = $scope.newFilter([])
    filter.name = null
    $scope.filters.push(filter)
    # $scope.apply(filter) # do not use new filter, just edit it
    $scope.edit(filter)

.directive 'listFilter', ($rootScope) ->
  templateUrl: '/navigation/filter.html'
  controller: 'NavigationFilterCtrl'
  transclude: true
  scope: true
  link: (scope, element, attrs) ->
    scope.listFilterTitle = attrs.filterTitle
    $rootScope.$on('editFilter', (event, filter) -> scope.edit(filter))


.directive 'editFilter', ->
  template:
    """
      <form class="edit-form">
        <input required focus type="text" placeholder="{{ placeholder }}"
          ng-model="editing.name">
      </form>
    """
  replace: true
  transclude: true
  restrict: 'E'
  priority: 0
  scope: true
  link: (scope, element, attrs) ->
    input = element.find('input')

    scope.placeholder = attrs.placeholder
    element.removeAttr('placeholder')
