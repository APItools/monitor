class AnalyticsPage
  include Capybara::DSL

  def add_dashboard
    click_on('Add Dashboard')
    new_dashboard = find('.dashboard.editing.new')
    new_dashboard.fill_in('new dashboard', with: 'new dashboard')
    new_dashboard.click_on('save dashboard')
  end

  def has_empty_charts?(count)
    current_dashboard.assert_selector('a', text: 'Add Chart', count: count)
  end

  def has_chart_modal?
    assert_selector('.modal.chart-edit')
  end

  def add_chart
    current_dashboard.click_on('Add Chart', match: :first)
  end

  def edit_chart
    current_dashboard.click_on('Edit', match: :first)
  end

  def current_dashboard
    find('.current-dashboard')
  end
end
