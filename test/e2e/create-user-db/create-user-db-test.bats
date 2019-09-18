#!/usr/bin/env bats

setup() {
  USER='foo'
  DB='foodb'
  PASS_LEN=32
  fixture="${BATS_TEST_DIRNAME}/create-user-db-test.mk"
}

teardown() {
  make -f "${fixture}" drop-user-db USER="$USER" DB="$DB"
}

@test "create-user-db prints a password" {
  result="$(make -f "${fixture}" create-user-db USER="$USER" DB="$DB" PASS_LEN="$PASS_LEN")"
  [ ${#result} -eq "$PASS_LEN" ]
}
