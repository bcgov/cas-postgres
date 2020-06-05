#!/usr/bin/env bats

POD=$($OC -n $OC_PROJECT get pods --selector app="${PROJECT_PREFIX}postgres-patroni",spilo-role=master --field-selector status.phase=Running -o name | cut -d '/' -f 2 );

function _psql() {
  $OC -n $OC_PROJECT exec $POD -- psql -qtA -v 'ON_ERROR_STOP=1' -c "$1"
}

function _pg_available_extension() {
  _psql "select default_version from pg_available_extensions where name='$1';"
}

function _pg_enabled_extension() {
  _psql "select extversion from pg_extension where extname='$1';"
}

@test "libxml is loaded" {
  run _psql "select '<foo>bar</foo>'::xml;";
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "<foo>bar</foo>" ]
}

# @test "citus is installed" {
#   run _pg_available_extension 'citus'
#   echo "${lines[@]}"
#   [ "$status" -eq 0 ]
#   [ "$output" = "8.2-2" ]
# }

# @test "citus is enabled by default" {
#   run _pg_enabled_extension 'citus'
#   echo "${lines[@]}"
#   [ "$status" -eq 0 ]
#   [ "$output" = "8.2-2" ]
# }

@test "pgcrypto is installed" {
  run _pg_available_extension 'pgcrypto'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "1.3" ]
}

@test "pgcrypto is not enabled by default" {
  run _pg_enabled_extension 'pgcrypto'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "plpgsql is installed" {
  run _pg_available_extension 'plpgsql'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0" ]
}

@test "plpgsql is enabled by default" {
  run _pg_enabled_extension 'plpgsql'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0" ]
}

@test "pgtap is installed" {
  run _pg_available_extension 'pgtap'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
}

@test "pgtap is not enabled by default" {
  run _pg_enabled_extension 'pgtap'
  echo "${lines[@]}"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
