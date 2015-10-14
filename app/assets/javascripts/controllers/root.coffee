angular.module('slug.root', ['ui.router', 'slug.setup'])
  .config ($urlRouterProvider) ->
    $urlRouterProvider.when('/', '/dashboard')
