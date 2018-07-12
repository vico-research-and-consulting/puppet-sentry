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


  if $sentry::version and (
      versioncmp($sentry::version, $sentry::params::version) < 0 or versioncmp($sentry::version, '8.0.0') >= 0
  ) {
    $sentry_http_params = "run web"
    $sentry_worker_params = "run worker"
  } else {
    $sentry_http_params = "start http"
    $sentry_worker_params = "celery worker -B"
  }

  anchor { 'sentry::service::begin': } ->

  supervisord::program {
    'sentry-http':
      command => "${command} ${sentry_http_params}",
    ;
    'sentry-worker':
      command => "${command} ${sentry_worker_params}",
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
