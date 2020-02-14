#!/usr/bin/env bats

setup() {
  user='foo'
  db='foodb'
  password='foopass'
  privilege='createrole'
  createdbfixture="${BATS_TEST_DIRNAME}/create-user-db-test.mk"
  fixture="${BATS_TEST_DIRNAME}/alter-role-test.mk"
  make --no-print-directory -f "${createdbfixture}" create-user-db USER="$user" DB="$db" PASS="$password"
}

teardown() {
  make --no-print-directory -f "${createdbfixture}" drop-user-db USER="$user" DB="$db"
}

@test "alter-role alters a user & adds createrole permission" {
  run make --no-print-directory -f "${fixture}" alter-role USER="$user" PRIVILEGE="$privilege"
  run make --no-print-directory -f "${fixture}" test-alter-role USER="$user" DB="$db" PASS="$password"
  echo "$output" # prints the lines if test fails
  [[ "${lines[0]}" =~ "t" ]]
}
