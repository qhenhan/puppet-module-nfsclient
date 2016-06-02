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
      $gss_line     = 'SECURE_NFS'
      $keytab_line  = 'RPCGSSDARGS'
      $service      = 'rpcgssd'
      $nfs_requires = Service['idmapd_service']
      if $::operatingsystemrelease =~ /^7/ {
        if $keytab {
          service { 'nfs-config':
            ensure    => 'running',
            enable    => true,
            subscribe => File_line['GSSD_OPTIONS'],
          }
          file { '/etc/krb5.keytab':
            ensure => 'symlink',
            target => '/etc/opt/quest/vas/host.keytab',
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
      $service     = 'nfs'
      # Setting nfs_requires to undef just fixes the code
      # Someone with better functional knowledge should fix functionality if needed or remove this comment.
      $nfs_requires = undef
      if $::operatingsystemrelease =~ /^11/ {
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
    }
    default: {
      fail("nfsclient module only supports Suse and RedHat. <${::osfamily}> was detected.")
    }
  }

  if $gss_real {
    include rpcbind
    include nfs::idmap

    file_line { 'NFS_SECURITY_GSS':
      path   => '/etc/sysconfig/nfs',
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
      path  => '/etc/sysconfig/nfs',
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
