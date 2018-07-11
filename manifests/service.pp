# == Class: sentry::service
#
# This class is meant to be called from sentry.
# It ensures the service is running.
#
class sentry::service
{
  $command = join([
    "${sentry::path}/virtualenv/bin/sentry",
    "--config=${sentry::path}/sentry.conf.py"
  ], ' ')

  Supervisord::Program {
    ensure          => present,
    directory       => $sentry::path,
    user            => $sentry::owner,
    autostart       => true,
    redirect_stderr => true,
  }

  anchor { 'sentry::service::begin': } ->

  if $sentry::version and (
      versioncmp($sentry::version, $sentry::params::version) < 0 or versioncmp($version, '8.0.0') >= 0
  ) {
    $sentry-http-params = "run web"
    $sentry-worker-params = "run worker"
  } else {
    $sentry-http-params = "start http"
    $sentry-worker-params = "celery worker -B"
  }

  supervisord::program {
    'sentry-http':
      command => "${command} ${sentry-http-params}",
    ;
    'sentry-worker':
      command => "${command} ${sentry-worker-params}",
    ;
  } ->

  anchor { 'sentry::service::end': }

  if $sentry::service_restart {
    Anchor['sentry::service::begin'] ~>

    supervisord::supervisorctl { 'sentry_reload':
      command     => 'reload',
      refreshonly => true,
    }
  }
}
