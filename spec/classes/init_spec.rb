require 'spec_helper'
describe 'nfsclient' do
  let :facts do
    {}
  end

  let :params do
    {}
  end

  let :options do
    {
      'gss' =>
        {
          'RedHat' => 'SECURE_NFS',
          'Suse' => 'NFS_SECURITY_GSS',
        },
      'keytab' =>
        {
          'RedHat' => 'RPCGSSDARGS',
          'Suse' => 'GSSD_OPTIONS',
        },
    }
  end

  context 'generic config' do
    on_supported_os.each do |os, facts|
      context "on os #{os}" do

        let(:facts) do
          facts
        end

        it 'should not do anything by default' do
          should compile
          should have_resource_count(0)
        end

        it 'should configure gss if specified' do
          params.merge!({'gss' => true})
          should contain_file_line('NFS_SECURITY_GSS').with(
          {
            'path' => '/etc/sysconfig/nfs',
            'line' => "#{options['gss'][facts[:osfamily]]}=\"yes\"",
            'match' => "^#{options['gss'][facts[:osfamily]]}=.*",
          })
          should contain_file_line('NFS_SECURITY_GSS').that_notifies('Service[rpcbind_service]')
        end

        it 'should configure keytab if specified' do
          params.merge!({'gss' => true, 'keytab' => '/etc/keytab'})
          should contain_file_line('GSSD_OPTIONS').with(
          {
            'path' => '/etc/sysconfig/nfs',
            'line' => "#{options['keytab'][facts[:osfamily]]}=\"-k /etc/keytab\"",
            'match' => "^#{options['keytab'][facts[:osfamily]]}=.*",
          })
          should contain_file_line('GSSD_OPTIONS').that_notifies('Service[rpcbind_service]')
        end

      end
    end
  end

  context 'specific config for SLES 11' do
    let :facts do
      {
        'osfamily'          => 'Suse',
        'lsbmajdistrelease' => '11',
      }
    end

    it 'should configure gssd and idmapd on SUSE 11' do
      params.merge!({'gss' => true})
      should contain_file_line('NFS_START_SERVICES').with(
      {
        'path' => '/etc/sysconfig/nfs',
        'line' => 'NFS_START_SERVICES="gssd,idmapd"',
        'match' => '^NFS_START_SERVICES=',
        'notify' => ['Exec[nfs-force-start]', 'Service[rpcbind_service]'],
      })
      should contain_file_line('MODULES_LOADED_ON_BOOT').with(
      {
        'path' => '/etc/sysconfig/kernel',
        'line' => 'MODULES_LOADED_ON_BOOT="rpcsec_gss_krb5"',
        'match' => '^MODULES_LOADED_ON_BOOT=',
        'notify' => 'Exec[gss-module-modprobe]',
      })
      should contain_exec('gss-module-modprobe').with(
      {
        'command' => 'modprobe rpcsec_gss_krb5',
        'unless' => 'lsmod | egrep "^rpcsec_gss_krb5"',
        'path' => '/sbin:/usr/bin',
        'refreshonly' => true,
      })
      should contain_exec('nfs-force-start').with(
      {
        'command' => 'service nfs force-start',
        'path' => '/sbin',
        'refreshonly' => true,
      })
    end
  end

  context 'specific config for SLES 12' do
    let :facts do
      {
        'osfamily'          => 'Suse',
        'lsbmajdistrelease' => '12',
      }
    end

    it 'should configure keytab on SUSE 12' do
      params.merge!({'gss' => true, 'keytab' => '/etc/keytab'})
      should contain_file_line('GSSD_OPTIONS').that_notifies('Service[nfs]')
    end

    it 'should manage nfs on SUSE 12' do
      params.merge!({'gss' => true})
      facts.merge!('lsbmajdistrelease' => '12')
      should contain_service('nfs').with(
      {
        'ensure' => 'running',
        'enable' => 'true',
      })
      should contain_file_line('NFS_SECURITY_GSS').that_notifies('Service[nfs]')
    end
  end

  context 'specific config for RHEL' do
    let :facts do
      {
        'osfamily'          => 'RedHat',
      }
    end

    it 'should manage rpcgssd' do
      params.merge!({'gss' => true})
      should contain_service('rpcgssd').with(
      {
        'ensure' => 'running',
        'enable' => true,
      })
      should contain_file_line('NFS_SECURITY_GSS').that_notifies('Service[rpcgssd]')
    end
  end

  context 'on unsupported os' do
    it 'should fail gracefully' do
      facts.merge!('osfamily' => 'UNSUPPORTED')
      should compile.and_raise_error(/nfsclient module only supports Suse. <UNSUPPORTED> was detected./)
    end
  end
end
