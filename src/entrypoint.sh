#!/bin/bash

# Exit script in case of error
set -e

INVOKE_LOG_STDOUT=${INVOKE_LOG_STDOUT:-FALSE}
invoke () {
    if [ "${INVOKE_LOG_STDOUT}" = 'true' ] || [ "${INVOKE_LOG_STDOUT}" = 'True' ]
    then
        # shellcheck disable=SC2068
        /usr/local/bin/invoke $@
    else
        # shellcheck disable=SC2068
        /usr/local/bin/invoke $@ > /tmp/invoke.log 2>&1
    fi
    # shellcheck disable=SC2145
    echo "$@ tasks done"
}

# Start cron && memcached services
service cron restart &

# shellcheck disable=SC2028
echo $"\n\n\n"
echo "-----------------------------------------------------"
echo "STARTING DJANGO ENTRYPOINT $(date)"
echo "-----------------------------------------------------"

invoke update

source $HOME/.bashrc
source $HOME/.override_env

echo DOCKER_API_VERSION=$DOCKER_API_VERSION
echo POSTGRES_USER=$POSTGRES_USER
echo POSTGRES_PASSWORD=$POSTGRES_PASSWORD
echo DATABASE_URL=$DATABASE_URL
echo GEODATABASE_URL=$GEODATABASE_URL
echo SITEURL=$SITEURL
echo ALLOWED_HOSTS=$ALLOWED_HOSTS
echo GEOSERVER_PUBLIC_LOCATION=$GEOSERVER_PUBLIC_LOCATION
echo MONITORING_ENABLED=$MONITORING_ENABLED
echo MONITORING_HOST_NAME=$MONITORING_HOST_NAME
echo MONITORING_SERVICE_NAME=$MONITORING_SERVICE_NAME
echo MONITORING_DATA_TTL=$MONITORING_DATA_TTL

# invoke waitfordbs

# shellcheck disable=SC2124
cmd="$@"

if [ "${IS_CELERY}" = "true" ] || [ "${IS_CELERY}" = "True" ]
then
    echo "Executing Celery server $cmd for Production"
elif [ "${FRESH_INSTALL}" = "true" ] || [ "${FRESH_INSTALL}" = "True" ]
then
    echo "Executing fresh installation tasks, this must be run only once"
    invoke migrations
    invoke createcachetable
    if [ "${FORCE_REINIT}" = "true" ]  || [ "${FORCE_REINIT}" = "True" ] || [ ! -e "/mnt/volumes/statics/geonode_init.lock" ]; then
        echo "Fresh install and force reinit is true"
        invoke prepare
        invoke fixtures
        invoke updateadmin
        invoke initialized
    fi
    invoke statics
else
    if [ "${RUN_MIGRATIONS}" = "true" ]  || [ "${RUN_MIGRATIONS}" = "True" ]
    then
        invoke migrations
    fi
    if [ "${FORCE_REINIT}" = "true" ]  || [ "${FORCE_REINIT}" = "True" ] || [ ! -e "/mnt/volumes/statics/geonode_init.lock" ]; then
        echo "force reinit is true"
        invoke prepare
        invoke fixtures
        invoke updateadmin
        invoke initialized
    fi
    echo "Executing UWSGI server $cmd for Production"
fi

echo "-----------------------------------------------------"
echo "FINISHED DJANGO ENTRYPOINT --------------------------"
echo "-----------------------------------------------------"

# Run the CMD
echo "got command $cmd"
exec $cmd