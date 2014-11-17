# Guard::Concat

This little guard allows you to concatenate js/css (or other) files in one.


## Install

Make sure you have [guard](http://github.com/guard/guard) installed.

Install the gem with:

    gem install guard-concat

Or add it to your Gemfile:

    gem 'guard-concat'

And then add a basic setup to your Guardfile:

    guard init concat


## Usage


``` ruby
# This will concatenate the javascript files a.js and b.js in public/js to all.js
guard :concat, type: "js", files: %w(b a), input_dir: "public/js", output: "public/js/all"

# analog css example
guard :concat, type: "css", files: %w(c d), input_dir: "public/css", output: "public/css/all"

# js example with *

guard :concat, type: "js", files: %w(vendor/* b a), input_dir: "public/js", output: "public/js/all"
# will concatenate all files in the vendor dir, then b then a (watch out of dependencies)
```

Advanced usage:

``` ruby
# this is a recommended file structure when using *
# plugins usually need libraries so put libraries like jquery in the libs directory, then your jquery (or another library) plugin(s) in the plugins dir and at the end your main file(s)
guard :concat, type: "js", files: %w(libs/* plugins/* main), input_dir: "public/js", output: "public/js/all"
```

it's not possible to use * or ./* alone, you have to use * after a directory name, like this: `dir/*`

## Versions changelog

- 0.0.4 - add star (*) support to load multiple files 
- 0.0.3 - basic version