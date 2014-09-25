angular.module('slug.root', ['ui.router'])
  .config ($urlRouterProvider) ->
    $urlRouterProvider.when('/', '/dashboard')
