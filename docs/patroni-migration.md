# Migrating from a legacy patroni HA cluster to a new Crunchy Postgres Operator deployment

# Step 1: Add a Crunchy PGO to your deployment

This is done with the [cas-postgres-cluster](helm/cas-postgres-cluster/Chart.yaml) chart.

> [!NOTE]
> We recommend making the database and the application completely independent.
> The cas-postgres-cluster chart can be added as a dependency, but this would mean losing your database if the application's chart were to be uninstalled.

To do this, create a `values.yaml` file somewhere with the configuration for your PGO cluster.
Then, install the chart:

```
helm install --values path/to/values.yaml --repo https://bcgov.github.io/cas-postgres/ my-database-cluster cas-postgres/cas-postgres-cluster
```

> [!NOTE]
> Make sure to setup the postgres cluster with the users your app needs (or to create them afterwards in your install process).
> PgBouncer will not allow connections with a Superuser role.
>
> For example:
>
> ```
>   users:
>    - name: postgres
>    - name: appuser
>      databases:
>        - myapp
> ```

> [!CAUTION]
> When setting up the `cas-postgres-cluster` chart, make sure the `namespace` value is different from your existing patroni cluster.
> Otherwise terraform will attempt to delete the existing backups and overwrite them with the new cluster ones!

#### Example with a makefile:

The original makefile was:

```makefile
install: helm upgrade --install ... my_app path/to/Chart/
```

The new makefile will look like this

```makefile
install_app: helm upgrade --install ... my_app path/to/Chart/

install_db: helm upgrade --install --values path/to/values.yaml my-database-cluster cas-postgres/cas-postgres-cluster

install: install_db install_app
```

Although not required, it's recommended to make a first release here.
There is now an empty postgres cluster next to your existing deployment.

> [!CAUTION]
> Extra caution: When setting up the `cas-postgres-cluster` chart, make sure the `namespace` value is different from your existing patroni cluster.
> Otherwise terraform will attempt to delete the existing backups and overwrite them with the new cluster ones!

# Step 2: Add the migration chart to the existing app deployment

Add the [patroni-migration](helm/patroni-migration/Chart.yaml) as a dependency of your app deployment.

This chart does, in order:

- Scale down the deployment passed into the values to 0 pods (to avoid having connections to the database)
- Copies the roles and passwords from the source cluster to the target cluster, except for the source user listed in the chart, and `postgres` roles
- Copies the database named in the values over to a new database in the target cluster.
- Assigns the migrated database to the provided app user

It should be configured with the old patroni deployment as a source (`from: ...`), and the new PGO cluster as the target (`to: ...`).

> [!NOTE]
> Note: the `ignoreRoles` value should include all the roles that are declared in the new postgres cluster chart (user roles need to be setup by PGO to be properly registered by pgbouncer). Including these roles in the migration will overwrite the setup done by PGO and cause connection issues.

#### Example values.yaml

```
migrationJob:
  image: postgres
  tag: 15
  ignoreRoles:
    - metabase

deployment:
  name: cas-metabase
  # for the KNP
  sourceReleaseName: cas-metabase
  targetReleaseName: cas-metabase-db
  originalReplicaCount: 2

from:
  # Assuming all database information will be in the same secret
  # Pass either the secret's key or the specific value
  secretName: cas-metabase-patroni
  hostSecretKey: ~
  host: cas-metabase-patroni.9212c9-dev.svc.cluster.local
  passwordSecretKey: password-superuser
  password: ~
  portSecretKey: ~
  port: 5432
  userSecretKey: ~
  user: postgres

  # The name of the database to migrate
  db: metabase

to:
  # This is necessarily a PGO deployment
  superuserSecretName: cas-metabase-db-cas-postgres-cluster-pguser-superuser
  appuserSecretName: cas-metabase-db-cas-postgres-cluster-pguser-metabase
```

# Step 3: Update your app deployment to target the new database cluster

1. Update the Deployment object, or all objects applicable, to use the connection strings or postgres environment variables from the newly created Postgres Operator.

2. Make sure the app has access to the new Postgres Operator cluster. **This may include adding new Kubernetes Network Policies.**

# Step 4: Create a deployment with steps #1, #2 and #3

Create a release! The `patroni-migration` chart will run as a pre-upgrade hook and will wait for the databases to be available to connect before initiating the migration. This lets us minimize the time spent with the app unavailable.

# Step 5: Cleanup

Create a new release removing the old patroni deployment, and removing the `patroni-migration` chart.
Things **_should_** just work!
