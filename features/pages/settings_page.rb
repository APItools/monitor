class SettingsPage
  include Capybara::DSL

  def has_form?
    fill_in('name', with: 'Github API')
    fill_in('url', with: 'https://api.github.com')
  end

end
