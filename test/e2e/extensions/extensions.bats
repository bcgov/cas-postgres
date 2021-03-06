#!/usr/bin/env bats

pod=""
remaining_tries=5
until [ -n "$pod" ]; do
  pod=$($OC -n "$OC_PROJECT" get pods --selector app="${PROJECT_PREFIX}postgres-patroni",spilo-role=master --field-selector status.phase=Running -o name | cut -d '/' -f 2 );
  if [ -z "$pod" ] && [ $remaining_tries -gt 0 ]; then
    sleep 5;
    remaining_tries=$((remaining_tries-1))
  fi;
  if [ -z "$pod" ] && [ $remaining_tries -eq 0 ]; then
    echo "couldn't get pod"
    exit 1
  fi
done

function _psql() {
  $OC -n "$OC_PROJECT" exec "$pod" -- psql -qtA -v 'ON_ERROR_STOP=1' -c "$1"
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
