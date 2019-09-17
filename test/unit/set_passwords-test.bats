#!/usr/bin/env bats

load ../test_helper

setup() {
    shellmock_clean

    SET_PASSWORDS="${BATS_TEST_DIRNAME}/../../root/usr/share/container-scripts/postgresql/start/set_passwords.sh"

    echo_input() {
        read INPUT
        echo "$INPUT"
    }
    export -f echo_input
}

teardown() {
    if [ -z "$TEST_FUNCTION" ]; then
        shellmock_clean
    fi

    export -n echo_input
}

@test "set_passwords.sh sets password for \$POSTGRESQL_USER if \$postinitdb_actions contains 'simple_db'" {
    export POSTGRESQL_USER="foo"
    export POSTGRESQL_PASSWORD="bar"
    export postinitdb_actions="simple_db"
    EXPECTED_ARGS="--set ON_ERROR_STOP=1 --set=username=$POSTGRESQL_USER --set=password=$POSTGRESQL_PASSWORD"
    shellmock_expect psql --match "$EXPECTED_ARGS" --exec "echo_input {}"

    run $SET_PASSWORDS

    [ "${lines[0]}" == "ALTER USER :\"username\" WITH ENCRYPTED PASSWORD :'password';" ]
}
