createdb -U postgres template_postgis

psql -U postgres -d template_postgis -c "CREATE EXTENSION postgis;"
ls -al /usr/share/postgresql/9.3/contrib
ls -al /usr/share/postgresql/9.3/extension
ls -al /usr/share/postgresql/9.3/contrib/postgis-2.1
psql -U postgres -d template_postgis -f "/usr/share/postgresql/9.3/contrib/postgis-2.1/legacy_gist.sql"
