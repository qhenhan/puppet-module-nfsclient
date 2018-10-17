# nfsclient
class nfsclient (
  $gss    = false,
  $keytab = undef,
) {

  if is_bool($gss) == true {
    $gss_real = $gss
  } else {
    $gss_real = str2bool($gss)
  }

  if $keytab != undef {
    validate_absolute_path($keytab)
  }

  case $::osfamily {
    'RedHat': {
      include nfs::idmap
      $gss_line     = 'SECURE_NFS'
      $keytab_line  = 'RPCGSSDARGS'
      $service      = 'rpcgssd'
      $nfs_requires = Service['idmapd_service']
      $nfs_sysconf  = '/etc/sysconfig/nfs'
      if $::operatingsystemrelease =~ /^7/ {
        if $keytab {
          service { 'nfs-config':
            ensure    => 'running',
            enable    => true,
            subscribe => File_line['GSSD_OPTIONS'],
          }
          file { '/etc/krb5.keytab':
            ensure => 'symlink',
            target => "${keytab}",
          }
          if $gss_real {
            Service['nfs-config'] ~> Service['rpcgssd']
            Service['rpcbind_service'] -> Service['rpcgssd']
            File['/etc/krb5.keytab'] {
              notify => Service['rpcgssd'],
            }
          }
        }
      }
    }
    'Suse': {
      $gss_line    = 'NFS_SECURITY_GSS'
      $keytab_line = 'GSSD_OPTIONS'
      # Setting nfs_requires to undef just fixes the code
      # Someone with better functional knowledge should fix functionality if needed or remove this comment.
      $nfs_requires = undef
      $nfs_sysconf  = '/etc/sysconfig/nfs'
      if $::operatingsystemrelease =~ /^11/ {
        $service = 'nfs'
        if $gss_real {
          file_line { 'NFS_START_SERVICES':
            match  => '^NFS_START_SERVICES=',
            path   => '/etc/sysconfig/nfs',
            line   => 'NFS_START_SERVICES="yes"',
            notify => [ Service[nfs], Service[rpcbind_service], ],
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
        }
      }
      if $::operatingsystemrelease =~ /^12/ {
        $service = 'rpc-gssd'
        if $keytab {
          file { '/etc/krb5.keytab':
            ensure => 'symlink',
            target => "${keytab}",
          }
        }
        if $gss_real {
          File['/etc/krb5.keytab'] {
            notify => Service["$service"],
          }
        }
      }
    }
    'Debian': {
      $gss_line     = 'NEED_GSSD'
      $keytab_line  = 'GSSDARGS'
      $service      = 'gssd'
      $nfs_requires = undef
      $nfs_sysconf  = '/etc/default/nfs-common'
      # Puppet 3.x Incorrectly defaults to upstart for Ubuntu 16.x
      if $::lsbmajdistrelease == '16' and $::lsbdistid == 'Ubuntu' {
        Service {
          provider => 'systemd',
        }
      }
      if $keytab {
        file { '/etc/krb5.keytab':
          ensure => 'symlink',
          target => "${keytab}",
        }
        if $gss_real {
          File['/etc/krb5.keytab'] {
            notify => Service["$service"],
          }
        }
      }
    }
    default: {
      fail("nfsclient module only supports Suse, RedHat and Debian. <${::osfamily}> was detected.")
    }
  }

  if $gss_real {
    include rpcbind

    file_line { 'NFS_SECURITY_GSS':
      path   => "${nfs_sysconf}",
      line   => "${gss_line}=\"yes\"",
      match  => "^${gss_line}=.*",
      notify => Service[rpcbind_service],
    }

    service { $service:
      ensure    => 'running',
      enable    => true,
      subscribe => File_line['NFS_SECURITY_GSS'],
    }

    if $nfs_requires {
      Service[$service] { require =>  $nfs_requires }
    }
  }
  if $keytab {
    file_line { 'GSSD_OPTIONS':
      path  => "${nfs_sysconf}",
      line  => "${keytab_line}=\"-k ${keytab}\"",
      match => "^${keytab_line}=.*",
    }
    if $gss_real {
      File_line['GSSD_OPTIONS'] {
        notify => [ Service[rpcbind_service], Service[$service], ],
      }
    }
  }
}
