#!/usr/bin/env bats

pod=""
remaining_tries=5
until [ -n "$pod" ]; do
  pod=$($OC -n "$OC_PROJECT" get pods --selector app="${PROJECT_PREFIX}postgres-patroni",spilo-role=master --field-selector status.phase=Running -o name | cut -d '/' -f 2 );
  if [ -z "$pod" ] && [ $remaining_tries -gt 0 ]; then
    sleep 1;
    remaining_tries=$((remaining_tries-1))
  fi;
  if [ -z "$pod" ] && [ $remaining_tries -eq 0 ]; then
    echo "couldn't get pod"
    exit 1
  fi
done

function _exec() {
  $OC -n "$OC_PROJECT" exec "$pod" -- /usr/bin/env bash -c "\'$*\'"
}

function _dropdb() {
  $OC -n "$OC_PROJECT" exec "$pod" -- psql -c "drop database if exists $1;"
}

function _dropuser() {
  $OC -n "$OC_PROJECT" exec "$pod" -- psql -c "drop role if exists $1;"
}

function _create_user_db() {
  $OC -n "$OC_PROJECT" exec "$pod" -- create-user-db "$@"
}

function _alter_role() {
  $OC -n "$OC_PROJECT" exec "$pod" -- create-user-db "$@"
}


setup() {
  user='foo'
  db='foodb'
  password='foopass'
  privilege='createrole'
}

teardown() {
  _dropdb $db
  _dropuser $user
}

@test "alter-role alters a user & adds createrole permission" {
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  _alter_role $user $privilege
  run _exec PGPASSWORD="$password" psql -tq -U "$user" -d "$db" -c "select rolcreaterole from pg_roles where rolname=\'$user\';"
  echo "$output" # prints the lines if test fails
  [[ "${lines[0]}" =~ "t" ]]
}
