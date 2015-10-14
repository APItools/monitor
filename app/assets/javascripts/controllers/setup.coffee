angular.module('slug.setup', ['ui.router', 'slug.user_settings'])

.config ($stateProvider) ->
  Config =
    config: (UserSettings) ->
      UserSettings.$promise

  $stateProvider
    .state 'setup',
      url: '/setup'
      templateUrl: '/setup/show.html'
      controller: 'SetupCtrl'
      resolve: Config

    .state 'pair',
      url: '/pair'
      templateUrl: '/setup/pair.html'
      controller: 'PairCtrl'
      resolve: Config

.controller 'SetupCtrl', ($scope, $state, config, flash, OnPremise) ->
  setup = $scope.setup = report_usage: true

  if config.get('set_up')
    $state.go('dashboard')

  $scope.saveSetup = ->
    failure = ->
      flash.error = 'There was an error when setting up this Traffic Monitor. Dou you have internet connection?'

    update_config = ->
      config.extend(report_usage: setup.report_usage, set_up: true)
      config.$promise.then ->
        flash.success = 'Successfully set up your Traffic Monitor'
        $state.go('dashboard')

    if setup.report_usage
      uuid = config.get('uuid')
      OnPremise.register(uuid).then(update_config, failure)
    else
      update_config()




.controller 'PairCtrl', ($scope, $state, Brain, OnPremise) ->
  Brain.$promise.then ->
    $scope.get_key = "#{Brain.host}/on_premise/link"

  $scope.setup = {}

  $scope.pair = () ->
    key = $scope.setup.pairing_key
    linking = OnPremise.link(key)

    linking.success ->
      $state.go('dashboard')
