Then(/^the service form should be some demo services$/) do
  expect(@new_service_page).to have_demo_services
end

Then(/^there should be demo calls of that service$/) do
  @demo_calls_page = @service_page.demo_calls_page
  expect(@demo_calls_page).to have_demo_calls
end

When(/^user uses the demo calls$/) do
  @demo_calls = @demo_calls_page.demo_calls
  @demo_calls.each do |demo_call|
    demo_call.find('button').click
  end

  # waits for all calls to complete
  expect(@demo_calls_page).not_to have_loading_demo_calls

  run_cron
end

Then(/^it should record traces of all demo calls$/) do
  expect(@service_page.traces_page).to have_traces(@demo_calls.length)
end

When(/^the user creates the "([^"]*)" demo service$/) do |name|
  @demo_service = create_demo(home_page.add_service, name)
end

Given(/^the user has "([^"]*)" demo service$/) do |name|
  @demo_service = create_demo(home_page.add_service, name)
end

When(/^the "(.*?)" demo service is selected and created$/) do |name|
  @demo_service = create_demo(@new_service_page, name)
end

def create_demo(service, name)
  demo_service = service.select_demo(name).create
  @service_page = demo_service.service_page
end
