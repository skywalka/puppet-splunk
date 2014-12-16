class splunk::install (
  $license          = $::splunk::license,
  $pkgname          = $::splunk::pkgname,
  $splunkadmin      = $::splunk::splunkadmin,
  $localusers       = $::splunk::localusers,
  $SPLUNKHOME       = $::splunk::SPLUNKHOME,
  $type             = $::splunk::type,
  $version          = $::splunk::version,
  $package_source   = $::splunk::package_source,
  $package_provider = $::splunk::package_provider,
  ) {

  package { $pkgname:
    ensure   => $version,
    provider => $package_provider,
    source   => $package_source,
  }->

  file { '/etc/init.d/splunk':
    ensure => present,
    mode   => '0700',
    owner  => 'root',
    group  => 'root',
    source => "puppet:///modules/splunk/${::osfamily}/etc/init.d/${pkgname}",
  } ->

  # Enable splunk on boot and accept the EULA
    case $operatingsystem {
        debian, ubuntu: {
            exec { "enable-splunk":
            command => "/opt/splunk/bin/splunk enable boot-start --no-prompt --answer-yes --accept-license",
            unless => "/usr/sbin/update-rc.d -n splunk defaults | grep -q 'already exist'",
            require => Package['splunk'],
            }
        }
        centos, redhat: {
            exec { "enable-splunk":
            command => "/opt/splunk/bin/splunk enable boot-start --no-prompt --answer-yes --accept-license",
            unless => "/sbin/chkconfig --list splunk | grep -q '3:on'",
            require => Package['splunk'],
            }
        }
    }

  # Start splunk for the first time
    exec { "start-splunk":
    command => "/opt/splunk/bin/splunk start --no-prompt --answer-yes --accept-license",
    unless  => "/usr/bin/test -f /etc/init.d/splunk",
    require => File['/etc/init.d/splunk'],
    before  => Service['splunk'],
    }

    exec { "change-ownership-to-splunk":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "/opt/splunk/bin/splunk stop; chown -R splunk:splunk /opt/splunk; touch /opt/splunk/changed-ownership-to-splunk",
    creates => "/opt/splunk/changed-ownership-to-splunk",
    require => Exec['enable-splunk'],
    }

    file { '/opt/splunk/changed-ownership-to-splunk':
    ensure => present,
    mode   => '0640',
    owner  => 'splunk',
    group  => 'splunk',
    require => Exec['change-ownership-to-splunk'],
    }

  # inifile
  ini_setting { 'Server Name':
    ensure  => present,
    path    => "${SPLUNKHOME}/etc/system/local/server.conf",
    section => 'general',
    setting => 'serverName',
    value   => $::fqdn,
  } ->
  ini_setting { 'SSL v3 only':
    ensure  => present,
    path    => "${SPLUNKHOME}/etc/system/local/server.conf",
    section => 'sslConfig',
    setting => 'supportSSLV3Only',
    value   => 'True',
  } ->

  file { "${SPLUNKHOME}/etc/splunk.license":
    ensure => present,
    mode   => '0644',
    owner  => 'splunk',
    group  => 'splunk',
    backup => true,
    source => $license,
  } ->

  # Users local to the Splunk install (e.g., admin)
  exec { "create-splunk-passwd-file":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "echo ':admin::' > /opt/splunk/etc/passwd",
    creates => "/opt/splunk/etc/passwd",
    require => Exec['enable-splunk'],
  }

  exec { "change-admin-passwd":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i 's,^:admin:.*,:admin:${splunk_admin_enc_password}::Administrator:admin:${splunk_admin_email}:,' /opt/splunk/etc/passwd",
    unless  => "grep '^:admin:$splunk_admin_enc_password:' /opt/splunk/etc/passwd",
    require => Exec['create-splunk-passwd-file'],
  }

  file { "/opt/splunk/etc/system/local/web.conf":
      ensure => present,
      mode => 640,
      owner => splunk,
      group => splunk,
      content => "[settings]\nenableSplunkWebSSL = 1\n",
      require => Exec['enable-splunk'],
  }

    exec { "add-minimum-diskusage":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '$ a\\[diskUsage]' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^\[diskUsage]' /opt/splunk/etc/system/local/server.conf",
    require => Package['splunk'],
    }

    exec { "set-minimum-diskusage":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '/^\[diskUsage]/a minFreeSpace = $splunk_minimum_diskusage' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^minFreeSpace' /opt/splunk/etc/system/local/server.conf",
    require => Exec['add-minimum-diskusage'],
    }

    exec { "change-minimum-diskusage":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '/^minFreeSpace/s/ = .*/ = $splunk_minimum_diskusage/' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^minFreeSpace = $splunk_minimum_diskusage' /opt/splunk/etc/system/local/server.conf",
    require => Exec['set-minimum-diskusage'],
    }

    group { "splunk":
        ensure => "present",
        gid    => 502,
    }

    user { "splunk":
        ensure   => 'present',
        uid      => "502",
        gid      => "502",
        comment  => "Splunk Server",
        shell    => "/bin/bash",
    }

  # recursively copy the contents of the auth dir
  # This is causing a restart on the second run. - TODO
  file { "${SPLUNKHOME}/etc/auth":
      mode    => '0600',
      owner   => 'splunk',
      group   => 'splunk',
      recurse => true,
      purge   => false,
      source  => 'puppet:///modules/splunk/noarch/opt/splunk/etc/auth',
      require => Exec['enable-splunk'],
  }
}
