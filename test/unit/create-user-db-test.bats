#!/usr/bin/env bats

load ../test_helper

setup() {
    #shellmock_clean
    create_user="${BATS_TEST_DIRNAME}/../../root/usr/bin/create-user-db"
}

teardown() {
    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi
}

@test "create-user-db calls psql" {
    # TODO: this unit test doesn't do much. It probably should be improved
    user='foo'
    db='bar'
    password='baz'
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run "$create_user" $user $db $password true
    echo "${lines[@]}" # prints the lines if test fails
    [ $status -eq 0 ]
    [ "${lines[0]}" == "called psql" ]
}

@test "create-user-db prints an error if less than three params are passed" {
    user='foo'
    db='bar'
    shellmock_expect psql --type regex --match ".*" --output "called psql"
    run "$create_user" $user $db
    echo "${lines[@]}" # prints the lines if test fails
    [ $status -eq 1 ]
    [ "${lines[0]}" == "Passed 2 parameters. Expected 3 or 4." ]
}
