# == Class: sentry::config
#
# This class is called from sentry for service config.
#
class sentry::config
{
  $password       = $sentry::password
  $secret_key     = $sentry::secret_key
  $email          = $sentry::email
  $url            = $sentry::url
  $host           = $sentry::host
  $port           = $sentry::port
  $workers        = $sentry::workers
  $database       = $sentry::database
  $beacon_enabled = $sentry::beacon_enabled
  $email_enabled  = $sentry::email_enabled
  $proxy_enabled  = $sentry::proxy_enabled
  $redis_enabled  = $sentry::redis_enabled
  $extra_config   = $sentry::extra_config

  $config = {
    'database' => merge(
      $sentry::params::database_config_default,
      $sentry::database_config
    ),
    'email'    => merge(
      $sentry::params::email_config_default,
      $sentry::email_config
    ),
    'redis'    => merge(
      $sentry::params::redis_config_default,
      $sentry::redis_config
    ),
  }

  exec { 'update setuptools':
    user    => $sentry::owner,
    cwd     => $sentry::path,
    timeout => $sentry::timeout,
    command => "${sentry::install::pip_command} install -U setuptools==35.0.2",
    unless  => "${sentry::install::pip_command} list | /bin/grep 'setuptools (35.0.2)'",
    before  => Sentry::Command['postconfig_upgrade'],
  } ->

  #Ideally would like a better way to handle this maybe using package and pip through
  #virtualenv.
  exec { 'lock raven version':
    user    => $sentry::owner,
    cwd     => $sentry::path,
    timeout => $sentry::timeout,
    command => "${sentry::install::pip_command} uninstall -y raven && ${sentry::install::pip_command} install raven==5.6.0",
    unless  => "${sentry::install::pip_command} list | /bin/grep 'raven (5.6.0)'",
    before  => Sentry::Command['postconfig_upgrade'],
  }

  file { "${sentry::path}/sentry.conf.py":
    ensure  => present,
    content => template('sentry/sentry.conf.py.erb'),
    owner   => $sentry::owner,
    group   => $sentry::group,
    mode    => '0640',
  } ->
  if $sentry::version and (
      versioncmp($sentry::version, $sentry::params::version) < 0 or versioncmp($sentry::version, '8.0.0') >= 0
  ) {
    file { "${sentry::path}/config.yml":
      ensure  => present,
      content => template('sentry/config.yml.erb'),
      owner   => $sentry::owner,
      group   => $sentry::group,
      mode    => '0640',
      require => File["${sentry::path}/sentry.conf.py"],
    }
  }

  file { "${sentry::path}/.initialized":
    ensure  => present,
    content => 'This file tells Puppet to avoid running an upgrade again on config change',
    owner   => $sentry::owner,
    group   => $sentry::group,
  } ~>

  sentry::command { 'postconfig_upgrade':
    command     => 'upgrade --noinput',
    refreshonly => true,
  } ~>

  sentry::command { 'create_superuser':
    command     => join([
      'createuser',
      "--email='${email}'",
      '--superuser',
      "--password='${password}'",
      '--no-input'
    ], ' '),
    refreshonly => true,
  }
}
