Feature: Analytics

  In order to allow users to get insights of their apps
  The users
  Should be able to create own dashboards with charts

  Scenario: Create new dashboard
    Given there is a service
     When user goes to analytics of that service
      And creates a new dashboard
     Then the dashboard should show 3 empty charts

  Scenario: Add a chart to a dashboard
    Given there is a service
      And there is a new dashboard of that service
      And it adds a new chart
     Then the edit chart dialog chart should be shown

  Scenario: Editing existing chart
    Given there is a service
     When user goes to analytics of that service
      And edits a chart
     Then the edit chart dialog chart should be shown
