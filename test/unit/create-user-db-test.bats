#!/usr/bin/env bats

load ../test_helper

setup() {
    #shellmock_clean

    CREATE_USER="${BATS_TEST_DIRNAME}/../../root/usr/bin/create-user-db"

    echo_input() {
        echo "$(</dev/stdin)"
    }
    export -f echo_input
}

teardown() {
    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi

    export -n echo_input
}

@test "create-user-db creates a user, db, and prints a password" {
    USER='foo'
    DB='bar'
    PASS_LEN=42
    EXPECTED_ARGS="--set db=$DB --set user=$USER --set password=[_A-Za-z0-9-]*"
    shellmock_expect psql --type regex --match "$EXPECTED_ARGS" --exec "echo_input {}"
    run $CREATE_USER $USER $DB $PASS_LEN
    echo "${lines[@]}" # prints the lines if test fails

    [ "${lines[0]}" == "CREATE DATABASE :'db';" ]
    [ "${lines[1]}" == "CREATE USER :'user' WITH ENCRYPTED PASSWORD :'password';" ]
    [ "${lines[2]}" == "GRANT ALL PRIVILEGES ON DATABASE :'db' TO :'user';" ]
    [ "${#lines[3]}" -eq $PASS_LEN ]
}

@test "create-user-db prints a password of length 16 by default" {
    USER='foo'
    DB='bar'
    EXPECTED_ARGS="--set db=$DB --set user=$USER --set password=[_A-Za-z0-9-]*"
    shellmock_expect psql --type regex --match "$EXPECTED_ARGS" --exec "echo_input {}"
    run $CREATE_USER $USER $DB
    echo "${lines[@]}" # prints the lines if test fails

    [ "${#lines[3]}" -eq 16 ]
}
