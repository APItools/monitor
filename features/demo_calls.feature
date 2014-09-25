Feature: Demo calls
  In order to keep users on our page
  The users
  Should have easy way how to play with the service

  Scenario: Creating demo service
    When the landing page is loaded
    And the user wants to create new service

    Then the service form should be some demo services

    When the "Echo" demo service is selected and created
    Then there should be demo calls of that service

  Scenario: Demo services have working demo calls
    When the user creates the "Echo" demo service
    Then there should be demo calls of that service

    When user uses the demo calls
    Then it should record traces of all demo calls

  @webkit
  Scenario: Default middlewares
    Given the default middleware specs are imported
      And the user has "Echo" demo service
      And the user is on pipeline page
      And search "cache" middleware
      And adds "Cache" middleware
      And saves the pipeline

    When makes a call to a proxy
    Then the last trace should not be cached

    When makes a call to a proxy
      And loads more traces
    Then the last trace should be cached

