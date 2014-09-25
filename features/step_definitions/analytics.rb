When(/^user goes to analytics of that service$/) do
  @analytics_page = @service_page.analytics_page
end

When(/^creates a new dashboard$/) do
  @analytics_page.add_dashboard
end

Then(/^the dashboard should show (\d+) empty charts$/) do |count|
  expect(@analytics_page).to have_empty_charts(count)
end

When(/^it adds a new chart$/) do
  @analytics_page.add_chart
end

Then(/^the edit chart dialog chart should be shown$/) do
  expect(@analytics_page).to have_chart_modal
end


And(/^there is a new dashboard of that service$/) do
  step('user goes to analytics of that service')
  step('creates a new dashboard')
end


And(/^edits a chart$/) do
  @analytics_page.edit_chart
end
