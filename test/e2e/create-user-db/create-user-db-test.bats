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
  [ "${#lines[0]}" -eq "$PASS_LEN" ]
}
