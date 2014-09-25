slug = angular.module('slug.controllers')

slug.controller 'NavController', ($scope, $state, Service, ServiceSubmenu) ->
  $scope.hideMenu = -> $state.is('welcome')
  $scope.submenu_template = '/services/_submenu.html'

  $scope.submenu = ServiceSubmenu
  $scope.submenu.services = Service.query()

slug.directive 'navigation', ->
  controller: 'NavController'
  scope: {}
