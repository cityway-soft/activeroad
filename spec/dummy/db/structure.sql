--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: boundaries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE boundaries (
    id integer NOT NULL,
    objectid character varying(255),
    name character varying(255),
    admin_level integer,
    postal_code character varying(255),
    insee_code character varying(255),
    geometry geometry(MultiPolygon,4326)
);


--
-- Name: boundaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE boundaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: boundaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE boundaries_id_seq OWNED BY boundaries.id;


--
-- Name: junction_conditionnal_costs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE junction_conditionnal_costs (
    id integer NOT NULL,
    junction_id integer,
    cost double precision,
    tags character varying(255),
    start_physical_road_id integer,
    end_physical_road_id integer
);


--
-- Name: junction_conditionnal_costs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE junction_conditionnal_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: junction_conditionnal_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE junction_conditionnal_costs_id_seq OWNED BY junction_conditionnal_costs.id;


--
-- Name: junctions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE junctions (
    id integer NOT NULL,
    objectid character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    geometry geometry(Point,4326),
    tags hstore,
    height double precision,
    waiting_constraint double precision
);


--
-- Name: junctions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE junctions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: junctions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE junctions_id_seq OWNED BY junctions.id;


--
-- Name: junctions_physical_roads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE junctions_physical_roads (
    physical_road_id integer,
    junction_id integer
);


--
-- Name: logical_roads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE logical_roads (
    id integer NOT NULL,
    name character varying(255),
    objectid character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    boundary_id integer
);


--
-- Name: logical_roads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE logical_roads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logical_roads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE logical_roads_id_seq OWNED BY logical_roads.id;


--
-- Name: physical_road_conditionnal_costs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE physical_road_conditionnal_costs (
    id integer NOT NULL,
    physical_road_id integer,
    cost double precision,
    tags character varying(255)
);


--
-- Name: physical_road_conditionnal_costs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE physical_road_conditionnal_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: physical_road_conditionnal_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE physical_road_conditionnal_costs_id_seq OWNED BY physical_road_conditionnal_costs.id;


--
-- Name: physical_roads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE physical_roads (
    id integer NOT NULL,
    objectid character varying(255),
    logical_road_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    geometry geometry(LineString,4326),
    tags hstore,
    length_in_meter double precision DEFAULT 0,
    minimum_width character varying(255),
    transport_mode character varying(255),
    uphill double precision,
    downhill double precision,
    slope character varying(255),
    cant character varying(255),
    covering character varying(255),
    steps_count integer,
    banisters_available boolean,
    tactile_band boolean,
    physical_road_type character varying(255),
    car boolean,
    bike boolean,
    train boolean,
    pedestrian boolean,
    name character varying(255),
    boundary_id integer,
    marker integer DEFAULT 0
);


--
-- Name: physical_roads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE physical_roads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: physical_roads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE physical_roads_id_seq OWNED BY physical_roads.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: street_numbers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE street_numbers (
    id integer NOT NULL,
    number character varying(255),
    location_on_road double precision,
    physical_road_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    geometry geometry(Point,4326),
    objectid character varying(255),
    tags hstore
);


--
-- Name: street_numbers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE street_numbers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: street_numbers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE street_numbers_id_seq OWNED BY street_numbers.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY boundaries ALTER COLUMN id SET DEFAULT nextval('boundaries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY junction_conditionnal_costs ALTER COLUMN id SET DEFAULT nextval('junction_conditionnal_costs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY junctions ALTER COLUMN id SET DEFAULT nextval('junctions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY logical_roads ALTER COLUMN id SET DEFAULT nextval('logical_roads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY physical_road_conditionnal_costs ALTER COLUMN id SET DEFAULT nextval('physical_road_conditionnal_costs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY physical_roads ALTER COLUMN id SET DEFAULT nextval('physical_roads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY street_numbers ALTER COLUMN id SET DEFAULT nextval('street_numbers_id_seq'::regclass);


--
-- Name: boundaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY boundaries
    ADD CONSTRAINT boundaries_pkey PRIMARY KEY (id);


--
-- Name: junction_conditionnal_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY junction_conditionnal_costs
    ADD CONSTRAINT junction_conditionnal_costs_pkey PRIMARY KEY (id);


--
-- Name: junctions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY junctions
    ADD CONSTRAINT junctions_pkey PRIMARY KEY (id);


--
-- Name: logical_roads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY logical_roads
    ADD CONSTRAINT logical_roads_pkey PRIMARY KEY (id);


--
-- Name: physical_road_conditionnal_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY physical_road_conditionnal_costs
    ADD CONSTRAINT physical_road_conditionnal_costs_pkey PRIMARY KEY (id);


--
-- Name: physical_roads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY physical_roads
    ADD CONSTRAINT physical_roads_pkey PRIMARY KEY (id);


--
-- Name: street_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY street_numbers
    ADD CONSTRAINT street_numbers_pkey PRIMARY KEY (id);


--
-- Name: index_boundaries_on_geometry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_boundaries_on_geometry ON boundaries USING gist (geometry);


--
-- Name: index_junction_conditionnal_costs_on_junction_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_junction_conditionnal_costs_on_junction_id ON junction_conditionnal_costs USING btree (junction_id);


--
-- Name: index_junctions_on_objectid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_junctions_on_objectid ON junctions USING btree (objectid);


--
-- Name: index_junctions_physical_roads_on_junction_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_junctions_physical_roads_on_junction_id ON junctions_physical_roads USING btree (junction_id);


--
-- Name: index_logical_roads_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_logical_roads_on_name ON logical_roads USING btree (name);


--
-- Name: index_logical_roads_on_objectid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_logical_roads_on_objectid ON logical_roads USING btree (objectid);


--
-- Name: index_physical_road_conditionnal_costs_on_physical_road_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_physical_road_conditionnal_costs_on_physical_road_id ON physical_road_conditionnal_costs USING btree (physical_road_id);


--
-- Name: index_physical_roads_on_geometry; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_physical_roads_on_geometry ON physical_roads USING gist (geometry);


--
-- Name: index_physical_roads_on_logical_road_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_physical_roads_on_logical_road_id ON physical_roads USING btree (logical_road_id);


--
-- Name: index_physical_roads_on_objectid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_physical_roads_on_objectid ON physical_roads USING btree (objectid);


--
-- Name: index_physical_roads_on_physical_road_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_physical_roads_on_physical_road_type ON physical_roads USING btree (physical_road_type);


--
-- Name: index_street_numbers_on_number_and_physical_road_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_street_numbers_on_number_and_physical_road_id ON street_numbers USING btree (number, physical_road_id);


--
-- Name: index_street_numbers_on_physical_road_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_street_numbers_on_physical_road_id ON street_numbers USING btree (physical_road_id);


--
-- Name: junctions_physical_roads_ids; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX junctions_physical_roads_ids ON junctions_physical_roads USING btree (physical_road_id, junction_id);


--
-- Name: junctions_tags; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX junctions_tags ON junctions USING gin (tags);


--
-- Name: physical_roads_tags; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX physical_roads_tags ON physical_roads USING gin (tags);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('20110914160756');

INSERT INTO schema_migrations (version) VALUES ('20120201114800');

INSERT INTO schema_migrations (version) VALUES ('20120201162800');

INSERT INTO schema_migrations (version) VALUES ('20120203154500');

INSERT INTO schema_migrations (version) VALUES ('20120401083409');

INSERT INTO schema_migrations (version) VALUES ('20120419093427');

INSERT INTO schema_migrations (version) VALUES ('20121010125851');

INSERT INTO schema_migrations (version) VALUES ('20121011124923');

INSERT INTO schema_migrations (version) VALUES ('20121012134251');

INSERT INTO schema_migrations (version) VALUES ('20121012134440');

INSERT INTO schema_migrations (version) VALUES ('20121012134457');

INSERT INTO schema_migrations (version) VALUES ('20121106095002');

INSERT INTO schema_migrations (version) VALUES ('20130419155438');

INSERT INTO schema_migrations (version) VALUES ('20130507162801');

INSERT INTO schema_migrations (version) VALUES ('20130509075631');

INSERT INTO schema_migrations (version) VALUES ('20130509081745');

INSERT INTO schema_migrations (version) VALUES ('20130513134422');

INSERT INTO schema_migrations (version) VALUES ('20130513134511');

INSERT INTO schema_migrations (version) VALUES ('20130607114951');

INSERT INTO schema_migrations (version) VALUES ('20130801151637');

INSERT INTO schema_migrations (version) VALUES ('20130809155019');

INSERT INTO schema_migrations (version) VALUES ('20130812143049');

INSERT INTO schema_migrations (version) VALUES ('20140206091734');

INSERT INTO schema_migrations (version) VALUES ('20140210132933');

INSERT INTO schema_migrations (version) VALUES ('20140219095521');

INSERT INTO schema_migrations (version) VALUES ('20140228072448');

INSERT INTO schema_migrations (version) VALUES ('20140304141150');

INSERT INTO schema_migrations (version) VALUES ('20140310083550');

INSERT INTO schema_migrations (version) VALUES ('20140317153437');