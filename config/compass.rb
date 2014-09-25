# Require any additional compass plugins here.
require 'neat'
require 'bourbon'

require 'bootstrap-sass'
require 'compass-flexbox'

# Set this to the root of your project when deployed:
http_path = "/"
css_dir = "app/assets/stylesheets/compiled"
sass_dir = "app/assets/stylesheets/"
images_dir = "app/assets/images"
javascripts_dir = "app/assets/javascripts"

asset_cache_buster :none

# Fix fucked up bootstrap-scss
::Sass.load_paths.delete(File.expand_path(File.join('..', 'vendor', 'assets', 'stylesheets')))
