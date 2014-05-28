return {
  enabled = function(name)
    local value = os.getenv(name)
    if value and value ~= '0' then return value else return false end
  end
}
