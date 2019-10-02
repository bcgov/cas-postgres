#!/usr/bin/env bats

setup() {
  user='foo'
  db='foodb'
  password='foopass'
  fixture="${BATS_TEST_DIRNAME}/create-user-db-test.mk"
}

teardown() {
  make --no-print-directory -f "${fixture}" drop-user-db USER="$user" DB="$db"
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
  [ "$(echo -e "${lines[0]}" | tr -d '[:space:]')" == "ok" ]
}

@test "create-user-db is idempotent" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${status}" -eq 0 ]
}

@test "create-user-db creates a user that fails to log in with the wrong password" {
  make --no-print-directory -f "${fixture}" create-user-db USER="$user" DB="$db" PASS="$password"
  run make --no-print-directory -f "${fixture}" test-user-password USER="$user" DB="$db" PASS="wrongpassword"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${lines[0]}" == "psql: FATAL:  password authentication failed for user \"$user\"" ]
}
