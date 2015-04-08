#!/bin/bash

if [[ ! -z $DRUPAL_START ]]; then
  supervisord -c /etc/supervisord.conf & sleep 20
  cd /var/www/html && drush cc all
  status=$?
  if [[ $status != 0 ]]; then
    drush rr
  fi
  cd /var/www/html && drush en master -y
  cd /var/www/html && drush master-execute --no-uninstall --scope=$DOMAIN -y && drush fra -y && drush updb -y && drush cc all
  status=$?
  if [[ $status != 0 ]]; then
    echo "Drupal release errored out on database config commands, please see output for more detail"
    exit 1
  fi
  echo "Finished applying updates for Drupal database"
  kill $(jobs -p)
  sleep 20
fi
supervisord -n -c /etc/supervisord.conf
