#Private Class to enable/disable HWF
class splunk::config::hwf (
  $SPLUNKHOME = $::splunk::SPLUNKHOME,
  $status  = 'enabled'
  ) {
  file { "${SPLUNKHOME}/etc/apps/SplunkForwarder/local":
    ensure  => 'directory',
    owner   => 'splunk',
    group   => 'splunk',
    require => Class['splunk::install'],
  }
  file { "${SPLUNKHOME}/etc/apps/SplunkForwarder/local/app.conf":
    ensure  => file,
    owner   => 'splunk',
    group   => 'splunk',
    mode    => '0644',
    require => Class['splunk::install'],
  }
  ini_setting { 'Enable Splunk HWF':
    ensure  => present,
    path    => "${SPLUNKHOME}/etc/apps/SplunkForwarder/local/app.conf",
    section => 'install',
    setting => 'state',
    value   => $status,
    require => Class['splunk::install'],
  }
  exec { "add-forwarder-license":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '$ a\\[license]' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^\[license]' /opt/splunk/etc/system/local/server.conf",
    require => Class['splunk::install'],
    notify => Service['splunk'],
  }
  exec { "set-forwarder-license":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '/^\[license]/a active_group = Forwarder' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^active_group' /opt/splunk/etc/system/local/server.conf",
    require => Exec['add-forwarder-license'],
    notify => Service['splunk'],
  }
  exec { "change-forwarder-license":
    path    => "/sbin:/bin/:/usr/bin:/usr/sbin:/usr/local/bin/",
    command => "sed -i '/^active_group/s/ = .*/ = Forwarder/' /opt/splunk/etc/system/local/server.conf",
    unless  => "grep '^active_group = Forwarder' /opt/splunk/etc/system/local/server.conf",
    require => Exec['set-forwarder-license'],
    notify => Service['splunk'],
  }
}
