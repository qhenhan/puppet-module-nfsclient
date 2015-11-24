require 'spec_helper'
describe 'nfsclient' do

  describe 'nfsclient_config' do
    let :facts do
      {
        :osfamily => 'Suse',
        :lsbmajdistrelease => '11',
      }
    end

    context 'with default params' do
      it { should compile }
    end
  end
end
