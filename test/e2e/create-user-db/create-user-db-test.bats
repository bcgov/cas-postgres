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
  $OC -n "$OC_PROJECT" exec "$pod" -- /usr/bin/env bash -c "$@"
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
  limited_privilege_user='not_the_owner'
  db='foodb'
  password='foopass'
}

teardown() {
  _dropdb $db
  _dropuser $user
  _dropuser $limited_privilege_user
}

@test "create-user-db exits with code 0" {
  run _create_user_db -u "$user" -d "$db" -p "$password" --owner
  echo "${lines[@]}" # prints the lines if test fails
  [ "${status}" -eq 0 ]
}

@test "create-user-db creates a user that can log in to the db" {
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  run _exec PGPASSWORD="$password" psql -tq -U "$user" -d "$db" -c "select \'ok\';"
  echo "${lines[@]}" # prints the lines if test fails
  [[ "${lines[0]}" =~ "ok" ]]
}

@test "create-user-db is idempotent" {
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  run _create_user_db -u "$user" -d "$db" -p "$password" --owner
  echo "${lines[@]}" # prints the lines if test fails
  [ "${status}" -eq 0 ]
}

@test "create-user-db updates the password" {
  _create_user_db -u "$user" -d "$db" -p "oldPassword" --owner
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  run _exec PGPASSWORD="$password" psql -tq -U "$user" -d "$db" -c "select \'ok\';"
  echo "${lines[@]}" # prints the lines if test fails
  [[ "${lines[0]}" =~ "ok" ]]
}

@test "create-user-db creates a user that fails to log in with the wrong password" {
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  run _exec PGPASSWORD="wrongpassword" psql -tq -U "$user" -d "$db" -c "select \'ok\';"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${lines[0]}" == "psql: FATAL:  password authentication failed for user \"$user\"" ]
}


@test "create-user-db creates a user that only has specific privileges in the specified schemas" {
  _create_user_db -u "$user" -d "$db" -p "$password" --owner
  _exec psql -d $db -c "create schema schema_foo;create schema schema_bar;create schema schema_baz;"
	## The schemas must have tables for the privileges to appear in the role_table_grants table
  _exec psql -d $db -c "create table schema_foo.foo (blah int);"
	_exec psql -d $db -c "create table schema_bar.foo (blah int);"
	_exec psql -d $db -c "create table schema_baz.foo (blah int);"
  _create_user_db -u "$limited_privilege_user" -d "$db" -p "$password" --schemas schema_foo,schema_bar --privileges select,insert
  _exec psql -d $db -tq -c "select distinct privilege_type from information_schema.role_table_grants where table_schema=\'schema_foo\' and grantee=\'$limited_privilege_user\' order by privilege_type;"

  echo "$output" # prints the lines if test fails
  [[ "${lines[-2]}" =~ "INSERT" ]]
  [[ "${lines[-1]}" =~ "SELECT" ]]
}
