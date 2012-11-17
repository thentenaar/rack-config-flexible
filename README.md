rack-config-flexible
====================

An alternative to Rack::Config, offering much greater flexibility.

Licensing
=========

This software is licensed under the [Simplified BSD License](http://en.wikipedia.org/wiki/BSD_licenses#2-clause_license_.28.22Simplified_BSD_License.22_or_.22FreeBSD_License.22.29) as described in the LICENSE file.

Installation
============

    gem install rack-config-flexible

Usage
=====

Just add something like this to your _config.ru_:

```ruby
require 'rack/config/flexible'

use Rack::Config::Flexible do
  environment :production
    section :data
      set :key => 'value'

  environment :development
    section :data
      set :key => 'dev_value'

  # Set the current environment
  environment :production
end
```

Of course, individual environments, sections, and even the entire configuration can be loaded from yaml files.

Accessing the Configuration Data
================================

The configuration can be accessed by downstream middleware via the Rack environment. In the Usage example,
you could access _key_'s value as follows:

```ruby
env['rack.config']['data.key']
```

and you can even modify values as follows:

```ruby
env['rack.config']['data.key'] = 'new_value'
```

if, and only if, the given key exists. The format for the hash key is _section.key_.

Loading an Environment/Section from Yaml
========================================

```ruby
require 'rack/config/flexible'

use Rack::Config::Flexible do
  environment :production
    section :data, 'cfg/production/data.yaml'

  environment :development, 'cfg/development.yaml'

  # Set the current environment
  environment :production
end
```

Any calls to _set_ after _environment_ or _section_ will override
data loaded from the yaml file if the same key is specified.
Otherwise, they'll just add the values to the hash per usual.

Loading the Entire Configuration from a Yaml
============================================

You can load the entire configuration from a single file, or a
directory tree.

This example loads from a single file:

```ruby
require 'rack/config/flexible'

use Rack::Config::Flexible :from_file => 'settings.yaml' do
  # Set the current environment to production
  environment :production
end
```

This one from a directory tree:

```ruby
require 'rack/config/flexible'

use Rack::Config::Flexible :from_file => 'settings' do
  # Set the current environment to production
  environment :production
end
```

The directory tree is expected to be laid out like:

	settings/environment/section.yaml

Where each directory under _settings_ is an _environment_, 
containg a separate yaml file for each _section_. 
The YAML file itself will only hold key-value pairs for
that particular _section_.

See the inline documentation for more details.

