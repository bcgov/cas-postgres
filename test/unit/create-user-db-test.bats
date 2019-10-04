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

@test "create-user-db calls psql" {

    user='foo'
    db='bar'
    password='baz'
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run $CREATE_USER $user $db $password
    echo "${lines[@]}" # prints the lines if test fails

    [ "${lines[0]}" == "called psql" ]
}

@test "create-user-db prints an error if less than three params are passed" {
    user='foo'
    db='bar'
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run $CREATE_USER $user $db
    echo "${lines[@]}" # prints the lines if test fails

    [ "${lines[0]}" == "Passed 2 parameters. Expected 3." ]
}
