--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: mrtglog; Type: TABLE; Schema: public; Owner: mrtgsql; Tablespace: 
--

CREATE TABLE mrtglog (
    target character varying(50) NOT NULL,
    date timestamp with time zone NOT NULL,
    avgin bigint NOT NULL,
    avgout bigint NOT NULL,
    peakin bigint NOT NULL,
    peakout bigint NOT NULL
);


ALTER TABLE public.mrtglog OWNER TO mrtgsql;

--
-- Name: mrtgtarget; Type: TABLE; Schema: public; Owner: mrtgsql; Tablespace: 
--

CREATE TABLE mrtgtarget (
    target character varying(50) NOT NULL,
    device character varying(50) NOT NULL,
    description character varying(50) NOT NULL,
    date timestamp with time zone NOT NULL
);


ALTER TABLE public.mrtgtarget OWNER TO mrtgsql;

--
-- Name: mrtglog_pkey; Type: CONSTRAINT; Schema: public; Owner: mrtgsql; Tablespace: 
--

ALTER TABLE ONLY mrtglog
    ADD CONSTRAINT mrtglog_pkey PRIMARY KEY (target, date);


--
-- Name: mrtgtarget_pkey; Type: CONSTRAINT; Schema: public; Owner: mrtgsql; Tablespace: 
--

ALTER TABLE ONLY mrtgtarget
    ADD CONSTRAINT mrtgtarget_pkey PRIMARY KEY (target);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--
