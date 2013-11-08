createdb -U postgres template_postgis

if [[ "$POSTGIS" == "2.0" ]]; then
  psql -U postgres -d template_postgis -c "CREATE EXTENSION postgis;"
  psql -U postgres -d template_postgis -c "CREATE EXTENSION postgis_topology;"
else
  createlang -U postgres plpgsql template_postgis
  psql -U postgres -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-1.5/postgis.sql
  psql -U postgres -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-1.5/spatial_ref_sys.sql
fi
