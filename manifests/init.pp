class nfsclient (
  $gss    = false,
  $keytab = undef,
) {

  case $::osfamily {
    'RedHat': {
      $gss_line = 'SECURE_NFS'
      $keytab_line = 'RPCGSSDARGS'
      if $gss {
        service { 'rpcgssd':
          ensure => 'running',
          enable => true,
        }
        File_line['NFS_SECURITY_GSS'] ~> Service['rpcgssd']
      }
    }
    'Suse': {
      $gss_line = 'NFS_SECURITY_GSS'
      $keytab_line = 'GSSD_OPTIONS'
      case $::lsbmajdistrelease {
        '11': {
          if $gss {
            file_line { 'NFS_START_SERVICES':
              match  => '^NFS_START_SERVICES=',
              path   => '/etc/sysconfig/nfs',
              line   => 'NFS_START_SERVICES="gssd,idmapd"',
              notify => [ Exec[nfs-force-start], Service[rpcbind_service], ],
            }
            file_line { 'MODULES_LOADED_ON_BOOT':
              match  => '^MODULES_LOADED_ON_BOOT=',
              path   => '/etc/sysconfig/kernel',
              line   => 'MODULES_LOADED_ON_BOOT="rpcsec_gss_krb5"',
              notify => Exec[gss-module-modprobe],
            }
            exec { 'gss-module-modprobe':
              command     => 'modprobe rpcsec_gss_krb5',
              unless      => 'lsmod | egrep "^rpcsec_gss_krb5"',
              path        => '/sbin:/usr/bin',
              refreshonly => true,
            }
            exec { 'nfs-force-start':
              command     => 'service nfs force-start',
              path        => '/sbin',
              refreshonly => true,
            }
          }
        }
        '12': {
          if $gss {
            service { 'nfs':
              ensure => 'running',
              enable => true,
            }
            File_line['NFS_SECURITY_GSS'] ~> Service['nfs']
            if $keytab {
              File_line['GSSD_OPTIONS'] ~> Service['nfs']
            }
          }
        }
        default: {
          fail("nfsclient module only supports Suse versions 11 and 12. <${::lsbmajdistrelease}> was detected.")
        }
      }
    }
    default: {
      fail("nfsclient module only supports Suse. <${::osfamily}> was detected.")
    }
  }

  if $gss {
    include rpcbind

    file_line { 'NFS_SECURITY_GSS':
      path   => '/etc/sysconfig/nfs',
      line   => "${gss_line}=\"yes\"",
      match  => "^${gss_line}=.*",
      notify => Service[rpcbind_service],
    }
  }
  if $keytab {
    file_line { 'GSSD_OPTIONS':
      path  => '/etc/sysconfig/nfs',
      line  => "${keytab_line}=\"-k ${keytab}\"",
      match => "^${keytab_line}=.*",
    }
    if $gss {
      File_line['GSSD_OPTIONS'] ~> Service['rpcbind_service']
    }
  }
}

