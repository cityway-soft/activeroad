createdb -U postgres template_postgis

psql -U postgres -d template_postgis -c "CREATE EXTENSION postgis;"
psql -U postgres -d template_postgis -f "/usr/share/postgresql/9.3/contrib/postgis-2.1/legacy_gist.sql"
