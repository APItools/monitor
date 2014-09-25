When(/^loads more traces$/) do
  @traces_page.load_more
end

Then(/^the last trace should (not )?be cached$/) do |negative|

  @traces_page = @service_page.traces_page

  expect(@traces_page).to have_a_trace

  last_trace = expect(@traces_page.last_trace)

  result = be_cached(negative)

  if negative
    last_trace.to_not result
  else
    last_trace.to result
  end

end


Then(/^it should see service traces$/) do
  expect(page).to have_text('Debug your API calls')
end
