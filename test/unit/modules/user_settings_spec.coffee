describe 'UserSettings', ->
  beforeEach module('slug.user_settings')

  it 'provides user settings service', inject (UserSettings) ->
    expect(UserSettings).toBeDefined()
    expect(UserSettings.get).toBeDefined()
    expect(UserSettings.set).toBeDefined()

    UserSettings.set('prop1', 'value1')
    expect(UserSettings.get('prop1')).toBe 'value1'
