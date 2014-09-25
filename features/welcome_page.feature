Feature: Welcome page

  In order to show users how monitoring can be useful
  The users
  Should have example dashboard on their first visit

  Scenario: Show welcome page when users first arrives
    When the landing page is loaded
    Then there should be a service dashboard empty

  Scenario: Show service dashboard when there are services
    Given there is a service
    When the landing page is loaded
    Then there should be a service dashboard
