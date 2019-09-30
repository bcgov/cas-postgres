#!/usr/bin/env bats

setup() {
  USER='foo'
  DB='foodb'
  PASS_LEN=32
  fixture="${BATS_TEST_DIRNAME}/create-user-db-test.mk"
}

teardown() {
  make --no-print-directory -f "${fixture}" drop-user-db USER="$USER" DB="$DB"
}

@test "create-user-db prints a password" {
  run make --no-print-directory -f "${fixture}" create-user-db USER="$USER" DB="$DB" PASS_LEN="$PASS_LEN"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${#lines[0]}" -eq "$PASS_LEN" ]
}

@test "create-user-db creates a user that can log in to the db" {
  PASS=$(make --no-print-directory -f "${fixture}" create-user-db USER="$USER" DB="$DB" PASS_LEN="$PASS_LEN")
  run make --no-print-directory -f "${fixture}" test-user-password USER="$USER" DB="$DB" PASS="$PASS"
  echo "${lines[@]}" # prints the lines if test fails
  [ "$(echo -e "${lines[0]}" | tr -d '[:space:]')" == "ok" ]
}

@test "create-user-db creates a user that fails to log in with the wrong password" {
  PASS=$(make --no-print-directory -f "${fixture}" create-user-db USER="$USER" DB="$DB" PASS_LEN="$PASS_LEN")
  run make --no-print-directory -f "${fixture}" test-user-password USER="$USER" DB="$DB" PASS="wrongpassword"
  echo "${lines[@]}" # prints the lines if test fails
  [ "${lines[0]}" == "psql: FATAL:  password authentication failed for user \"$USER\"" ]
}
