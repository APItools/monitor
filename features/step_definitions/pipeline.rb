Given(/^the default middleware specs are imported$/) do
  api.post('system/initialize')
end

When(/^the user is on pipeline page$/) do
  @pipeline_page = @service_page.pipeline_page
end

When (/^search "([^"]*)" middleware$/) do |name|
  within(".middleware-search-form") do
    fill_in 'search', :with => name
  end
  find('.middleware-search-submit').click
end


When(/^adds "([^"]*)" middleware$/) do |name|
  @pipeline_page.add_middleware(name)

  expect(@pipeline_page).to have_middleware(name)
end

When(/^saves the pipeline$/) do
  @pipeline_page.save_pipeline
end
