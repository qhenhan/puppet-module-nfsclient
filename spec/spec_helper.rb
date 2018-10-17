# <remove deprecation warning when running spec tests>
RSpec.configure do |config|
  config.mock_with :rspec
end
# </remove deprecation warning when running spec tests>

require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |config|
  config.hiera_config = 'spec/fixtures/hiera/hiera.yaml'
  config.before :each do
    # Ensure that we don't accidentally cache facts and environment between
    # test cases.  This requires each example group to explicitly load the
    # facts being exercised with something like
    # Facter.collection.loader.load(:ipaddress)
    Facter.clear
    Facter.clear_messages
  end
  config.default_facts = {
    :osfamily                  => 'RedHat',
    :operatingsystemrelease    => '7.5',
    :operatingsystemmajrelease => '7', # nfs::idmap
  }
end
