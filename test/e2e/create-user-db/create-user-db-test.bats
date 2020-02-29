#!/usr/bin/env bats

setup() {
  user='foo'
  limited_privilege_user='not_the_owner'
  db='foodb'
  password='foopass'
  fixture="${BATS_TEST_DIRNAME}/create-user-db-test.mk"
}

teardown() {
  make --no-print-directory -f "${fixture}" drop-user-db USER="$user" DB="$db"
  make --no-print-directory -f "${fixture}" drop-user-db USER="$limited_privilege_user" DB="$db"
}

@test "create-user-db exits with code 0" {
  run make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${status}" -eq 0 ]
}

@test "create-user-db creates a user that can log in to the db" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" test-user-password USER="$user" DB="$db" PASS="$password"
  echo "${lines[@]}" # prints the lines if test fails
  [[ "${lines[0]}" =~ "ok" ]]
}

@test "create-user-db is idempotent" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${status}" -eq 0 ]
}

@test "create-user-db updates the password" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="oldPassword"
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" test-user-password USER="$user" DB="$db" PASS="$password"
  echo "${lines[@]}" # prints the lines if test fails
  [[ "${lines[0]}" =~ "ok" ]]
}

@test "create-user-db creates a user that fails to log in with the wrong password" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" test-user-password USER="$user" DB="$db" PASS="wrongpassword"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${lines[0]}" == "psql: FATAL:  password authentication failed for user \"$user\"" ]
}


@test "create-user-db creates a user that only has specific privileges in the specified schemas" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  make --no-print-directory -f "${fixture}" create-user-db-privileges USER="$limited_privilege_user" DB="$db" PASS="qwerty"
  run make --no-print-directory -f "${fixture}" get-user-tables-privileges USER="$limited_privilege_user" DB="$db" SCHEMA="schema_foo"
  echo "$output" # prints the lines if test fails
  [[ "${lines[-2]}" =~ "INSERT" ]]
  [[ "${lines[-1]}" =~ "SELECT" ]]
}
