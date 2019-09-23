#!/usr/bin/env bats

load ../test_helper

setup() {
    #shellmock_clean
    CREATE_USER="${BATS_TEST_DIRNAME}/../../root/usr/bin/create-user-db"
}

teardown() {
    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi
}

@test "create-user-db creates a user, db, and prints a password" {

    USER='foo'
    DB='bar'
    PASS_LEN=42
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run $CREATE_USER $USER $DB $PASS_LEN
    echo "${lines[@]}" # prints the lines if test fails

    [ "${#lines[0]}" -eq $PASS_LEN ]
}

@test "create-user-db prints a password of length 16 by default" {
    USER='foo'
    DB='bar'
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run $CREATE_USER $USER $DB
    echo "${lines[@]}" # prints the lines if test fails

    [ "${#lines[0]}" -eq 16 ]
}
