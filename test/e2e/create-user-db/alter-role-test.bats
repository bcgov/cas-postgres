#!/usr/bin/env bats

pod=$($OC -n "$OC_PROJECT" get pods --selector app="${PROJECT_PREFIX}postgres-patroni",spilo-role=master --field-selector status.phase=Running -o name | cut -d '/' -f 2 );

function _exec() {
  $OC -n "$OC_PROJECT" exec "$pod" -- /usr/bin/env bash -c "$@"
}

function _dropdb() {
  $OC -n "$OC_PROJECT" exec "$pod" -- dropdb --if-exists "$1"
}

function _dropuser() {
  $OC -n "$OC_PROJECT" exec "$pod" -- dropuser --if-exists "$1"
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
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
}

teardown() {
  _dropdb $db
  _dropuser $user
}

@test "alter-role alters a user & adds createrole permission" {
  _alter_role $user $privilege
  run _exec PGPASSWORD="$password" psql -tq -U "$user" -d "$db" -c "select rolcreaterole from pg_roles where rolname=\'$user\';"
  echo "$output" # prints the lines if test fails
  [[ "${lines[0]}" =~ "t" ]]
}
