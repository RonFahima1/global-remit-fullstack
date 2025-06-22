--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:J7EMUYdOfKYm57DI32ATTw==$1F/JRMskR4ih6Ik1E5shrFCthEHxcIjqvxhz8+yQyIs=:d/CdXxVOpELNH972XvUc+N1iTANLdtGP3cU+ZTzqQdE=';






--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 14.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- PostgreSQL database dump complete
--

--
-- Database "global_remit" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 14.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: global_remit; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE global_remit WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';


ALTER DATABASE global_remit OWNER TO postgres;

\connect global_remit

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- Name: compliance; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA compliance;


ALTER SCHEMA compliance OWNER TO postgres;

--
-- Name: config; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA config;


ALTER SCHEMA config OWNER TO postgres;

--
-- Name: core; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA core;


ALTER SCHEMA core OWNER TO postgres;

--
-- Name: participant_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.participant_type AS ENUM (
    'sender',
    'receiver',
    'fee',
    'tax',
    'commission',
    'adjustment',
    'system'
);


ALTER TYPE public.participant_type OWNER TO postgres;

--
-- Name: transaction_direction; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.transaction_direction AS ENUM (
    'credit',
    'debit'
);


ALTER TYPE public.transaction_direction OWNER TO postgres;

--
-- Name: transaction_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.transaction_status AS ENUM (
    'pending',
    'completed',
    'failed',
    'cancelled',
    'reversed',
    'hold'
);


ALTER TYPE public.transaction_status OWNER TO postgres;

--
-- Name: user_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_status AS ENUM (
    'PENDING_VERIFICATION',
    'ACTIVE',
    'DISABLED',
    'SUSPENDED',
    'LOCKED',
    'DELETED',
    'INVITED',
    'PASSWORD_EXPIRED'
);


ALTER TYPE public.user_status OWNER TO postgres;

--
-- Name: can_change_password(uuid, character varying); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.can_change_password(p_user_id uuid, p_new_password_hash character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_password_count INTEGER;
    v_password_exists BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO v_password_count
    FROM auth.user_password_history
    WHERE user_id = p_user_id
    ORDER BY changed_at DESC
    LIMIT 5;
    
    SELECT EXISTS(
        SELECT 1 FROM auth.user_password_history 
        WHERE user_id = p_user_id AND password_hash = p_new_password_hash
    ) INTO v_password_exists;
    
    RETURN NOT v_password_exists;
END;
$$;


ALTER FUNCTION auth.can_change_password(p_user_id uuid, p_new_password_hash character varying) OWNER TO postgres;

--
-- Name: create_user_invitation(character varying, integer, uuid, integer); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.create_user_invitation(p_email character varying, p_role_id integer, p_invited_by uuid, p_expires_in_hours integer DEFAULT 72) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_invitation_id UUID;
    v_token VARCHAR(255);
BEGIN
    v_token := encode(gen_random_bytes(32), 'hex');
    
    INSERT INTO auth.user_invitations (
        email, token, role_id, invited_by, expires_at
    ) VALUES (
        p_email, v_token, p_role_id, p_invited_by, 
        NOW() + (p_expires_in_hours || ' hours')::INTERVAL
    ) RETURNING id INTO v_invitation_id;
    
    RETURN v_invitation_id;
END;
$$;


ALTER FUNCTION auth.create_user_invitation(p_email character varying, p_role_id integer, p_invited_by uuid, p_expires_in_hours integer) OWNER TO postgres;

--
-- Name: log_user_activity(uuid, character varying, text, inet, text, jsonb); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.log_user_activity(p_user_id uuid, p_activity_type character varying, p_description text DEFAULT NULL::text, p_ip_address inet DEFAULT NULL::inet, p_user_agent text DEFAULT NULL::text, p_metadata jsonb DEFAULT NULL::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO auth.user_activity_log (
        user_id, activity_type, description, ip_address, user_agent, metadata
    ) VALUES (
        p_user_id, p_activity_type, p_description, p_ip_address, p_user_agent, p_metadata
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;


ALTER FUNCTION auth.log_user_activity(p_user_id uuid, p_activity_type character varying, p_description text, p_ip_address inet, p_user_agent text, p_metadata jsonb) OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: password_reset_tokens; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.password_reset_tokens OWNER TO postgres;

--
-- Name: permissions; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.permissions (
    id integer NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    category character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.permissions OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: auth; Owner: postgres
--

CREATE SEQUENCE auth.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.permissions_id_seq OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: postgres
--

ALTER SEQUENCE auth.permissions_id_seq OWNED BY auth.permissions.id;


--
-- Name: role_permissions; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.role_permissions (
    role_id integer NOT NULL,
    permission_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.role_permissions OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.roles (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    is_system boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: auth; Owner: postgres
--

CREATE SEQUENCE auth.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: postgres
--

ALTER SEQUENCE auth.roles_id_seq OWNED BY auth.roles.id;


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    user_agent text,
    ip_address inet,
    expires_at timestamp with time zone NOT NULL,
    last_activity timestamp with time zone DEFAULT now() NOT NULL,
    is_revoked boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.sessions OWNER TO postgres;

--
-- Name: user_activity_log; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_activity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    activity_type character varying(50) NOT NULL,
    description text,
    ip_address inet,
    user_agent text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.user_activity_log OWNER TO postgres;

--
-- Name: user_invitations; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    role_id integer NOT NULL,
    invited_by uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    accepted_by uuid,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_invitations_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACCEPTED'::character varying, 'EXPIRED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE auth.user_invitations OWNER TO postgres;

--
-- Name: user_password_history; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_password_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    password_hash character varying(255) NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by uuid,
    is_temporary boolean DEFAULT false NOT NULL
);


ALTER TABLE auth.user_password_history OWNER TO postgres;

--
-- Name: user_preferences; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_preferences (
    user_id uuid NOT NULL,
    language character varying(10) DEFAULT 'en'::character varying,
    timezone character varying(50) DEFAULT 'UTC'::character varying,
    theme character varying(20) DEFAULT 'light'::character varying,
    notifications jsonb DEFAULT '{}'::jsonb,
    preferences jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.user_preferences OWNER TO postgres;

--
-- Name: user_roles; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_roles (
    user_id uuid NOT NULL,
    role_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


ALTER TABLE auth.user_roles OWNER TO postgres;

--
-- Name: user_sessions; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    session_token character varying(255) NOT NULL,
    refresh_token character varying(255),
    ip_address inet,
    user_agent text,
    device_info jsonb,
    is_active boolean DEFAULT true NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    last_activity timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.user_sessions OWNER TO postgres;

--
-- Name: user_verification_tokens; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_verification_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token character varying(255) NOT NULL,
    token_type character varying(20) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_verification_tokens_token_type_check CHECK (((token_type)::text = ANY ((ARRAY['EMAIL'::character varying, 'PHONE'::character varying, 'PASSWORD_RESET'::character varying])::text[])))
);


ALTER TABLE auth.user_verification_tokens OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    password_hash character varying(255) NOT NULL,
    password_changed_at timestamp with time zone,
    password_reset_token character varying(100),
    password_reset_expires_at timestamp with time zone,
    mfa_enabled boolean DEFAULT false NOT NULL,
    mfa_secret character varying(100),
    mfa_recovery_codes text[],
    status public.user_status DEFAULT 'PENDING_VERIFICATION'::public.user_status NOT NULL,
    failed_login_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    phone character varying(20),
    phone_verified boolean DEFAULT false NOT NULL,
    last_login_at timestamp with time zone,
    last_login_ip inet,
    last_login_user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    version integer DEFAULT 1 NOT NULL,
    employee_id character varying(50),
    hire_date date,
    termination_date date,
    manager_id uuid,
    department character varying(100),
    "position" character varying(100),
    branch_id uuid,
    address text,
    city character varying(100),
    state character varying(100),
    postal_code character varying(20),
    country character(2),
    phone_verified_at timestamp with time zone,
    email_verified_at timestamp with time zone,
    password_expires_at timestamp with time zone,
    last_password_change timestamp with time zone,
    password_history text[],
    login_count integer DEFAULT 0 NOT NULL,
    invitation_token character varying(255),
    invitation_expires_at timestamp with time zone,
    invitation_accepted_at timestamp with time zone,
    invited_by uuid,
    status_reason text,
    status_changed_at timestamp with time zone,
    status_changed_by uuid,
    notes text,
    metadata jsonb,
    must_change_password boolean DEFAULT false NOT NULL,
    updated_by uuid,
    deleted_by uuid
);


ALTER TABLE auth.users OWNER TO postgres;

--
-- Name: aml_checks; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.aml_checks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid,
    transaction_id uuid,
    check_type character varying(50) NOT NULL,
    check_status character varying(20) NOT NULL,
    risk_score integer,
    risk_level character varying(20),
    check_data jsonb,
    notes text,
    resolved_at timestamp with time zone,
    resolved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_aml_status CHECK (((check_status)::text = ANY ((ARRAY['pending'::character varying, 'passed'::character varying, 'failed'::character varying, 'manual_review'::character varying])::text[]))),
    CONSTRAINT chk_risk_level CHECK (((risk_level)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying])::text[])))
);


ALTER TABLE compliance.aml_checks OWNER TO postgres;

--
-- Name: audit_logs; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    event_type character varying(50) NOT NULL,
    table_name character varying(100),
    record_id uuid,
    user_id uuid,
    user_ip inet,
    user_agent text,
    action character varying(20) NOT NULL,
    old_values jsonb,
    new_values jsonb,
    CONSTRAINT chk_audit_action CHECK (((action)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying, 'LOGIN'::character varying, 'LOGOUT'::character varying, 'AUTH_FAILED'::character varying])::text[])))
);


ALTER TABLE compliance.audit_logs OWNER TO postgres;

--
-- Name: blacklist_hits; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.blacklist_hits (
    id bigint NOT NULL,
    client_id uuid,
    transaction_id uuid,
    hit_date timestamp with time zone DEFAULT now() NOT NULL,
    blacklist_source text NOT NULL,
    hit_details jsonb NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.blacklist_hits OWNER TO postgres;

--
-- Name: blacklist_hits_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.blacklist_hits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.blacklist_hits_id_seq OWNER TO postgres;

--
-- Name: blacklist_hits_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.blacklist_hits_id_seq OWNED BY compliance.blacklist_hits.id;


--
-- Name: case_attachments; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.case_attachments (
    id bigint NOT NULL,
    case_id bigint,
    file_name text NOT NULL,
    file_url text NOT NULL,
    description text,
    uploaded_by uuid,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.case_attachments OWNER TO postgres;

--
-- Name: case_attachments_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.case_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.case_attachments_id_seq OWNER TO postgres;

--
-- Name: case_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.case_attachments_id_seq OWNED BY compliance.case_attachments.id;


--
-- Name: case_audit_log; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.case_audit_log (
    id bigint NOT NULL,
    case_id bigint,
    event_type text NOT NULL,
    event_details jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.case_audit_log OWNER TO postgres;

--
-- Name: case_audit_log_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.case_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.case_audit_log_id_seq OWNER TO postgres;

--
-- Name: case_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.case_audit_log_id_seq OWNED BY compliance.case_audit_log.id;


--
-- Name: case_management; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.case_management (
    id bigint NOT NULL,
    client_id uuid,
    case_type text NOT NULL,
    status text NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    assigned_to uuid,
    case_details jsonb NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.case_management OWNER TO postgres;

--
-- Name: case_management_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.case_management_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.case_management_id_seq OWNER TO postgres;

--
-- Name: case_management_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.case_management_id_seq OWNED BY compliance.case_management.id;


--
-- Name: case_notes; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.case_notes (
    id bigint NOT NULL,
    case_id bigint,
    note_text text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.case_notes OWNER TO postgres;

--
-- Name: case_notes_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.case_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.case_notes_id_seq OWNER TO postgres;

--
-- Name: case_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.case_notes_id_seq OWNED BY compliance.case_notes.id;


--
-- Name: kyc_verifications; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.kyc_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    verification_type character varying(50) NOT NULL,
    verification_status character varying(20) NOT NULL,
    verified_at timestamp with time zone,
    verified_by uuid,
    expiration_date timestamp with time zone,
    verification_data jsonb,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_verification_status CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'expired'::character varying])::text[])))
);


ALTER TABLE compliance.kyc_verifications OWNER TO postgres;

--
-- Name: pep_screenings; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.pep_screenings (
    id bigint NOT NULL,
    client_id uuid,
    transaction_id uuid,
    screening_date timestamp with time zone DEFAULT now() NOT NULL,
    pep_source text NOT NULL,
    screening_details jsonb NOT NULL,
    is_pep boolean DEFAULT false NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.pep_screenings OWNER TO postgres;

--
-- Name: pep_screenings_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.pep_screenings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.pep_screenings_id_seq OWNER TO postgres;

--
-- Name: pep_screenings_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.pep_screenings_id_seq OWNED BY compliance.pep_screenings.id;


--
-- Name: risk_assessments; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.risk_assessments (
    id bigint NOT NULL,
    client_id uuid,
    transaction_id uuid,
    assessment_date timestamp with time zone DEFAULT now() NOT NULL,
    risk_score numeric(5,2) NOT NULL,
    risk_level text NOT NULL,
    assessment_details jsonb NOT NULL,
    assessed_by uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.risk_assessments OWNER TO postgres;

--
-- Name: risk_assessments_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.risk_assessments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.risk_assessments_id_seq OWNER TO postgres;

--
-- Name: risk_assessments_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.risk_assessments_id_seq OWNED BY compliance.risk_assessments.id;


--
-- Name: sanctions_matches; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.sanctions_matches (
    id bigint NOT NULL,
    client_id uuid,
    transaction_id uuid,
    match_date timestamp with time zone DEFAULT now() NOT NULL,
    match_source text NOT NULL,
    match_details jsonb NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.sanctions_matches OWNER TO postgres;

--
-- Name: sanctions_matches_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.sanctions_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.sanctions_matches_id_seq OWNER TO postgres;

--
-- Name: sanctions_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.sanctions_matches_id_seq OWNED BY compliance.sanctions_matches.id;


--
-- Name: watchlist_hits; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.watchlist_hits (
    id bigint NOT NULL,
    client_id uuid,
    transaction_id uuid,
    hit_date timestamp with time zone DEFAULT now() NOT NULL,
    watchlist_source text NOT NULL,
    hit_details jsonb NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE compliance.watchlist_hits OWNER TO postgres;

--
-- Name: watchlist_hits_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.watchlist_hits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.watchlist_hits_id_seq OWNER TO postgres;

--
-- Name: watchlist_hits_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.watchlist_hits_id_seq OWNED BY compliance.watchlist_hits.id;


--
-- Name: currencies; Type: TABLE; Schema: config; Owner: postgres
--

CREATE TABLE config.currencies (
    code character(3) NOT NULL,
    name character varying(100) NOT NULL,
    symbol character varying(10) NOT NULL,
    decimal_places integer DEFAULT 2 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_base_currency boolean DEFAULT false NOT NULL,
    is_fiat boolean DEFAULT true NOT NULL,
    is_crypto boolean GENERATED ALWAYS AS ((NOT is_fiat)) STORED,
    format_pattern character varying(50) DEFAULT '#,##0.00'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_decimal_places CHECK (((decimal_places >= 0) AND (decimal_places <= 8)))
);


ALTER TABLE config.currencies OWNER TO postgres;

--
-- Name: exchange_rates; Type: TABLE; Schema: config; Owner: postgres
--

CREATE TABLE config.exchange_rates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    from_currency character(3) NOT NULL,
    to_currency character(3) NOT NULL,
    rate numeric(24,12) NOT NULL,
    effective_date date NOT NULL,
    expiry_date date,
    is_active boolean DEFAULT true NOT NULL,
    source character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE config.exchange_rates OWNER TO postgres;

--
-- Name: fee_structure_rules; Type: TABLE; Schema: config; Owner: postgres
--

CREATE TABLE config.fee_structure_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fee_structure_id uuid NOT NULL,
    rule_type character varying(50) NOT NULL,
    rule_condition jsonb NOT NULL,
    fee_value numeric(20,4) NOT NULL,
    fee_percentage numeric(5,2),
    min_amount numeric(20,4),
    max_amount numeric(20,4),
    currency character(3),
    priority integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_rule_type CHECK (((rule_type)::text = ANY ((ARRAY['amount_range'::character varying, 'transaction_type'::character varying, 'account_type'::character varying, 'customer_tier'::character varying, 'channel'::character varying])::text[])))
);


ALTER TABLE config.fee_structure_rules OWNER TO postgres;

--
-- Name: fee_structures; Type: TABLE; Schema: config; Owner: postgres
--

CREATE TABLE config.fee_structures (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    fee_type character varying(50) NOT NULL,
    calculation_method character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    applies_to_all_transaction_types boolean DEFAULT false NOT NULL,
    applies_to_all_account_types boolean DEFAULT false NOT NULL,
    applies_to_all_currencies boolean DEFAULT false NOT NULL,
    min_fee_amount numeric(20,4),
    max_fee_amount numeric(20,4),
    fee_percentage numeric(5,2),
    fixed_fee_amount numeric(20,4),
    fee_currency character(3),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_calculation_method CHECK (((calculation_method)::text = ANY ((ARRAY['fixed'::character varying, 'percentage'::character varying, 'tiered'::character varying, 'volume_based'::character varying])::text[]))),
    CONSTRAINT chk_fee_type CHECK (((fee_type)::text = ANY ((ARRAY['transaction'::character varying, 'account'::character varying, 'service'::character varying, 'penalty'::character varying, 'other'::character varying])::text[])))
);


ALTER TABLE config.fee_structures OWNER TO postgres;

--
-- Name: settings; Type: TABLE; Schema: config; Owner: postgres
--

CREATE TABLE config.settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    setting_key character varying(100) NOT NULL,
    setting_value text,
    data_type character varying(20) NOT NULL,
    description text,
    is_encrypted boolean DEFAULT false NOT NULL,
    is_sensitive boolean DEFAULT false NOT NULL,
    min_value text,
    max_value text,
    allowed_values jsonb,
    category character varying(50) NOT NULL,
    subcategory character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_data_type CHECK (((data_type)::text = ANY ((ARRAY['string'::character varying, 'number'::character varying, 'boolean'::character varying, 'json'::character varying, 'date'::character varying, 'datetime'::character varying])::text[])))
);


ALTER TABLE config.settings OWNER TO postgres;

--
-- Name: account_balances; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.account_balances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    balance_date date NOT NULL,
    opening_balance numeric(19,4) NOT NULL,
    closing_balance numeric(19,4) NOT NULL,
    total_credits numeric(19,4) DEFAULT 0 NOT NULL,
    total_debits numeric(19,4) DEFAULT 0 NOT NULL,
    transaction_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_positive_balances CHECK (((opening_balance >= (0)::numeric) AND (closing_balance >= (0)::numeric) AND (total_credits >= (0)::numeric) AND (total_debits >= (0)::numeric)))
);


ALTER TABLE core.account_balances OWNER TO postgres;

--
-- Name: account_holders; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.account_holders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    client_id uuid NOT NULL,
    holder_type character varying(20) DEFAULT 'PRIMARY'::character varying NOT NULL,
    added_date date DEFAULT CURRENT_DATE NOT NULL,
    removed_date date,
    permissions jsonb DEFAULT '{"view": true, "manage": false, "transact": true}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT account_holders_holder_type_check CHECK (((holder_type)::text = ANY ((ARRAY['PRIMARY'::character varying, 'JOINT'::character varying, 'AUTHORIZED'::character varying, 'BENEFICIARY'::character varying, 'POWER_OF_ATTORNEY'::character varying])::text[]))),
    CONSTRAINT chk_holder_type CHECK (((holder_type)::text = ANY ((ARRAY['PRIMARY'::character varying, 'JOINT'::character varying, 'AUTHORIZED'::character varying, 'BENEFICIARY'::character varying, 'POWER_OF_ATTORNEY'::character varying])::text[]))),
    CONSTRAINT chk_removal_date CHECK (((removed_date IS NULL) OR ((removed_date IS NOT NULL) AND (removed_date >= added_date))))
);


ALTER TABLE core.account_holders OWNER TO postgres;

--
-- Name: account_limits; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.account_limits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    limit_type character varying(50) NOT NULL,
    currency_code character(3) NOT NULL,
    limit_value numeric(20,4) NOT NULL,
    period character varying(20) NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    expiry_date date,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.account_limits OWNER TO postgres;

--
-- Name: account_products; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.account_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    product_id uuid NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    unassigned_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.account_products OWNER TO postgres;

--
-- Name: account_types; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.account_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type_code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    restrictions jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.account_types OWNER TO postgres;

--
-- Name: accounts; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_number character varying(20) NOT NULL,
    account_name character varying(255) NOT NULL,
    account_type_id uuid NOT NULL,
    currency_code character(3) NOT NULL,
    current_balance numeric(19,4) DEFAULT 0 NOT NULL,
    available_balance numeric(19,4) DEFAULT 0 NOT NULL,
    hold_balance numeric(19,4) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    open_date date DEFAULT CURRENT_DATE NOT NULL,
    last_activity_date date,
    close_date date,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    client_id uuid NOT NULL,
    CONSTRAINT accounts_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'DORMANT'::character varying, 'RESTRICTED'::character varying, 'CLOSED'::character varying])::text[]))),
    CONSTRAINT chk_account_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'DORMANT'::character varying, 'RESTRICTED'::character varying, 'CLOSED'::character varying])::text[]))),
    CONSTRAINT chk_available_balance CHECK ((available_balance <= current_balance)),
    CONSTRAINT chk_balance_non_negative CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT chk_dates CHECK (((close_date IS NULL) OR ((close_date IS NOT NULL) AND (close_date >= open_date)))),
    CONSTRAINT chk_hold_balance CHECK ((hold_balance <= current_balance))
);


ALTER TABLE core.accounts OWNER TO postgres;

--
-- Name: addresses; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    address_type character varying(30) NOT NULL,
    line1 character varying(255) NOT NULL,
    line2 character varying(255),
    city character varying(100) NOT NULL,
    state character varying(100),
    postal_code character varying(20),
    country_code character(2) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.addresses OWNER TO postgres;

--
-- Name: branches; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.branches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_name character varying(150) NOT NULL,
    branch_code character varying(20),
    address text,
    city character varying(100),
    state character varying(100),
    postal_code character varying(20),
    country_code character(2),
    phone character varying(30),
    email character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.branches OWNER TO postgres;

--
-- Name: client_profile_logs; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.client_profile_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    changed_by uuid,
    change_type character varying(50),
    old_values jsonb,
    new_values jsonb,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    reason text,
    version integer
);


ALTER TABLE core.client_profile_logs OWNER TO postgres;

--
-- Name: client_versions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.client_versions (
    version_id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    version integer NOT NULL,
    data jsonb NOT NULL,
    modified_by uuid,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    reason_for_change text
);


ALTER TABLE core.client_versions OWNER TO postgres;

--
-- Name: clients; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_number character varying(20) NOT NULL,
    client_type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    title character varying(10),
    first_name character varying(100) NOT NULL,
    middle_name character varying(100),
    last_name character varying(100) NOT NULL,
    date_of_birth date,
    gender character varying(10),
    marital_status character varying(20),
    email character varying(255),
    email_verified boolean DEFAULT false NOT NULL,
    phone character varying(20),
    phone_verified boolean DEFAULT false NOT NULL,
    occupation character varying(100),
    employer_name character varying(200),
    employment_status character varying(50),
    annual_income numeric(15,2),
    kyc_status character varying(20) DEFAULT 'NOT_VERIFIED'::character varying NOT NULL,
    kyc_verified_at timestamp with time zone,
    kyc_verified_by uuid,
    risk_level character varying(20) DEFAULT 'LOW'::character varying NOT NULL,
    relationship_manager_id uuid,
    referral_source character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    branch_id uuid,
    CONSTRAINT chk_client_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'CLOSED'::character varying, 'DECEASED'::character varying])::text[]))),
    CONSTRAINT chk_client_type CHECK (((client_type)::text = ANY ((ARRAY['INDIVIDUAL'::character varying, 'BUSINESS'::character varying, 'ORGANIZATION'::character varying])::text[]))),
    CONSTRAINT chk_phone_format CHECK (((phone IS NULL) OR ((phone)::text ~* '^\\+?[0-9\\s-]+$'::text))),
    CONSTRAINT clients_client_type_check CHECK (((client_type)::text = ANY ((ARRAY['INDIVIDUAL'::character varying, 'BUSINESS'::character varying, 'ORGANIZATION'::character varying])::text[]))),
    CONSTRAINT clients_gender_check CHECK (((gender)::text = ANY ((ARRAY['MALE'::character varying, 'FEMALE'::character varying, 'OTHER'::character varying, 'UNSPECIFIED'::character varying])::text[]))),
    CONSTRAINT clients_kyc_status_check CHECK (((kyc_status)::text = ANY ((ARRAY['NOT_VERIFIED'::character varying, 'PENDING'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying, 'EXPIRED'::character varying])::text[]))),
    CONSTRAINT clients_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'CLOSED'::character varying, 'DECEASED'::character varying])::text[])))
);


ALTER TABLE core.clients OWNER TO postgres;

--
-- Name: custom_field_values; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.custom_field_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    field_id uuid NOT NULL,
    field_name character varying(100) NOT NULL,
    value text,
    data_type character varying(20) DEFAULT 'string'::character varying NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.custom_field_values OWNER TO postgres;

--
-- Name: custom_fields; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.custom_fields (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type character varying(50) NOT NULL,
    field_name character varying(100) NOT NULL,
    label character varying(100) NOT NULL,
    data_type character varying(20) DEFAULT 'string'::character varying NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    options jsonb,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.custom_fields OWNER TO postgres;

--
-- Name: documents; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_type character varying(30) NOT NULL,
    owner_id uuid NOT NULL,
    document_type character varying(50) NOT NULL,
    file_name character varying(255) NOT NULL,
    file_url text NOT NULL,
    mime_type character varying(100) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    metadata jsonb,
    uploaded_by uuid,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.documents OWNER TO postgres;

--
-- Name: messages; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sender_type character varying(20) NOT NULL,
    sender_id uuid NOT NULL,
    recipient_type character varying(20) NOT NULL,
    recipient_id uuid NOT NULL,
    message_type character varying(50) NOT NULL,
    subject character varying(255),
    body text NOT NULL,
    status character varying(20) DEFAULT 'sent'::character varying NOT NULL,
    direction character varying(10) DEFAULT 'out'::character varying NOT NULL,
    metadata jsonb,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.messages OWNER TO postgres;

--
-- Name: notifications; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_type character varying(20) NOT NULL,
    recipient_id uuid NOT NULL,
    notification_type character varying(50) NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    status character varying(20) DEFAULT 'unread'::character varying NOT NULL,
    priority character varying(20) DEFAULT 'normal'::character varying NOT NULL,
    metadata jsonb,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.notifications OWNER TO postgres;

--
-- Name: product_features; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.product_features (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    feature_name character varying(100) NOT NULL,
    feature_value text,
    data_type character varying(20) DEFAULT 'string'::character varying NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.product_features OWNER TO postgres;

--
-- Name: products; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    product_type character varying(50) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    features jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.products OWNER TO postgres;

--
-- Name: transaction_limits; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.transaction_limits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transaction_type_id uuid,
    client_id uuid,
    account_id uuid,
    limit_type character varying(50) NOT NULL,
    currency_code character(3) NOT NULL,
    limit_value numeric(20,4) NOT NULL,
    period character varying(20) NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    expiry_date date,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.transaction_limits OWNER TO postgres;

--
-- Name: transaction_types; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.transaction_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    direction public.transaction_direction NOT NULL,
    affects_balance boolean DEFAULT true NOT NULL,
    requires_approval boolean DEFAULT false NOT NULL,
    approval_threshold numeric(20,4),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.transaction_types OWNER TO postgres;

--
-- Name: transactions; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transaction_reference character varying(50) NOT NULL,
    transaction_type_id uuid NOT NULL,
    status public.transaction_status DEFAULT 'pending'::public.transaction_status NOT NULL,
    amount numeric(20,4) NOT NULL,
    currency_code character(3) NOT NULL,
    exchange_rate numeric(20,10) DEFAULT 1,
    fee_amount numeric(20,4) DEFAULT 0,
    tax_amount numeric(20,4) DEFAULT 0,
    net_amount numeric(20,4) NOT NULL,
    transaction_date timestamp with time zone DEFAULT now() NOT NULL,
    value_date date,
    parent_transaction_id uuid,
    related_transaction_id uuid,
    branch_id uuid,
    teller_id uuid,
    description text,
    notes text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_net_amount CHECK ((net_amount > (0)::numeric)),
    CONSTRAINT chk_transaction_amount CHECK ((amount > (0)::numeric)),
    CONSTRAINT chk_transaction_status CHECK ((status = ANY (ARRAY['pending'::public.transaction_status, 'completed'::public.transaction_status, 'failed'::public.transaction_status, 'cancelled'::public.transaction_status, 'reversed'::public.transaction_status, 'hold'::public.transaction_status])))
);


ALTER TABLE core.transactions OWNER TO postgres;

--
-- Name: user_limits; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.user_limits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    limit_type character varying(50) NOT NULL,
    currency_code character(3) NOT NULL,
    limit_value numeric(20,4) NOT NULL,
    period character varying(20) NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    expiry_date date,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL
);


ALTER TABLE core.user_limits OWNER TO postgres;

--
-- Name: goose_db_version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goose_db_version (
    id integer NOT NULL,
    version_id bigint NOT NULL,
    is_applied boolean NOT NULL,
    tstamp timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.goose_db_version OWNER TO postgres;

--
-- Name: goose_db_version_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.goose_db_version ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.goose_db_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: permissions id; Type: DEFAULT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.permissions ALTER COLUMN id SET DEFAULT nextval('auth.permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.roles ALTER COLUMN id SET DEFAULT nextval('auth.roles_id_seq'::regclass);


--
-- Name: blacklist_hits id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.blacklist_hits ALTER COLUMN id SET DEFAULT nextval('compliance.blacklist_hits_id_seq'::regclass);


--
-- Name: case_attachments id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_attachments ALTER COLUMN id SET DEFAULT nextval('compliance.case_attachments_id_seq'::regclass);


--
-- Name: case_audit_log id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_audit_log ALTER COLUMN id SET DEFAULT nextval('compliance.case_audit_log_id_seq'::regclass);


--
-- Name: case_management id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_management ALTER COLUMN id SET DEFAULT nextval('compliance.case_management_id_seq'::regclass);


--
-- Name: case_notes id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_notes ALTER COLUMN id SET DEFAULT nextval('compliance.case_notes_id_seq'::regclass);


--
-- Name: pep_screenings id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.pep_screenings ALTER COLUMN id SET DEFAULT nextval('compliance.pep_screenings_id_seq'::regclass);


--
-- Name: risk_assessments id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.risk_assessments ALTER COLUMN id SET DEFAULT nextval('compliance.risk_assessments_id_seq'::regclass);


--
-- Name: sanctions_matches id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches ALTER COLUMN id SET DEFAULT nextval('compliance.sanctions_matches_id_seq'::regclass);


--
-- Name: watchlist_hits id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.watchlist_hits ALTER COLUMN id SET DEFAULT nextval('compliance.watchlist_hits_id_seq'::regclass);


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.password_reset_tokens (id, user_id, token_hash, expires_at, is_used, created_at) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.permissions (id, code, name, description, category, created_at) FROM stdin;
\.


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.role_permissions (role_id, permission_id, created_at) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.roles (id, name, description, is_system, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.sessions (id, user_id, token_hash, user_agent, ip_address, expires_at, last_activity, is_revoked, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_activity_log; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_activity_log (id, user_id, activity_type, description, ip_address, user_agent, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: user_invitations; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_invitations (id, email, token, role_id, invited_by, expires_at, accepted_at, accepted_by, status, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_password_history; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_password_history (id, user_id, password_hash, changed_at, changed_by, is_temporary) FROM stdin;
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_preferences (user_id, language, timezone, theme, notifications, preferences, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_roles (user_id, role_id, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_sessions (id, user_id, session_token, refresh_token, ip_address, user_agent, device_info, is_active, expires_at, last_activity, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_verification_tokens; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_verification_tokens (id, user_id, token, token_type, expires_at, used_at, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.users (id, username, email, email_verified, password_hash, password_changed_at, password_reset_token, password_reset_expires_at, mfa_enabled, mfa_secret, mfa_recovery_codes, status, failed_login_attempts, locked_until, first_name, last_name, phone, phone_verified, last_login_at, last_login_ip, last_login_user_agent, created_at, updated_at, deleted_at, version, employee_id, hire_date, termination_date, manager_id, department, "position", branch_id, address, city, state, postal_code, country, phone_verified_at, email_verified_at, password_expires_at, last_password_change, password_history, login_count, invitation_token, invitation_expires_at, invitation_accepted_at, invited_by, status_reason, status_changed_at, status_changed_by, notes, metadata, must_change_password, updated_by, deleted_by) FROM stdin;
227fb9a6-c50b-41f2-badc-334db8496735	agentuser	agentuser@example.com	t	$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Agent	User	\N	f	\N	\N	\N	2025-06-22 11:14:06.945506+00	2025-06-22 11:14:06.945506+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
8125e514-ec72-47dd-b07a-1062ec2312f2	complianceuser	complianceuser@example.com	t	$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Compliance	User	\N	f	\N	\N	\N	2025-06-22 11:14:06.945914+00	2025-06-22 11:14:06.945914+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
22f8b3e3-22c1-4ac3-9cbe-318443504b4d	orguser	orguser@example.com	t	$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Org	User	\N	f	\N	\N	\N	2025-06-22 11:14:06.94634+00	2025-06-22 11:14:06.94634+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
7809f3eb-afe9-4954-9eee-83025f43e957	viewer	viewer@example.com	t	$2b$12$u1Qw8Qw8Qw8Qw8Qw8Qw8QeQw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Qw8Q	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Global	Viewer	\N	f	\N	\N	\N	2025-06-22 11:14:06.946763+00	2025-06-22 11:14:06.946763+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
c2d67733-afe6-4512-acac-fd9150bf068e	agentadmin	agentadmin@example.com	t	$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Agent	Admin	\N	f	2025-06-22 11:18:21.307822+00	\N	\N	2025-06-22 11:14:06.944849+00	2025-06-22 11:14:06.944849+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
3191383c-b565-4135-a34c-ee9cd6987c91	orgadmin	orgadmin@example.com	t	$2b$12$5RZp0YVAs0xNP18VEPz6tOIxEfRWkFXBpkkqCsDKF5MnjkzZCeKi.	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Org	Admin	\N	f	2025-06-22 11:24:07.079885+00	\N	\N	2025-06-22 11:14:06.942767+00	2025-06-22 11:14:06.942767+00	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N
\.


--
-- Data for Name: aml_checks; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.aml_checks (id, client_id, transaction_id, check_type, check_status, risk_score, risk_level, check_data, notes, resolved_at, resolved_by, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.audit_logs (id, event_time, event_type, table_name, record_id, user_id, user_ip, user_agent, action, old_values, new_values) FROM stdin;
\.


--
-- Data for Name: blacklist_hits; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.blacklist_hits (id, client_id, transaction_id, hit_date, blacklist_source, hit_details, resolved, resolved_by, resolved_at, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: case_attachments; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.case_attachments (id, case_id, file_name, file_url, description, uploaded_by, uploaded_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: case_audit_log; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.case_audit_log (id, case_id, event_type, event_details, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: case_management; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.case_management (id, client_id, case_type, status, opened_at, closed_at, assigned_to, case_details, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: case_notes; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.case_notes (id, case_id, note_text, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: kyc_verifications; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.kyc_verifications (id, client_id, verification_type, verification_status, verified_at, verified_by, expiration_date, verification_data, rejection_reason, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: pep_screenings; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.pep_screenings (id, client_id, transaction_id, screening_date, pep_source, screening_details, is_pep, resolved, resolved_by, resolved_at, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: risk_assessments; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.risk_assessments (id, client_id, transaction_id, assessment_date, risk_score, risk_level, assessment_details, assessed_by, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sanctions_matches; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.sanctions_matches (id, client_id, transaction_id, match_date, match_source, match_details, resolved, resolved_by, resolved_at, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: watchlist_hits; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.watchlist_hits (id, client_id, transaction_id, hit_date, watchlist_source, hit_details, resolved, resolved_by, resolved_at, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: currencies; Type: TABLE DATA; Schema: config; Owner: postgres
--

COPY config.currencies (code, name, symbol, decimal_places, is_active, is_base_currency, is_fiat, format_pattern, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: exchange_rates; Type: TABLE DATA; Schema: config; Owner: postgres
--

COPY config.exchange_rates (id, from_currency, to_currency, rate, effective_date, expiry_date, is_active, source, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: fee_structure_rules; Type: TABLE DATA; Schema: config; Owner: postgres
--

COPY config.fee_structure_rules (id, fee_structure_id, rule_type, rule_condition, fee_value, fee_percentage, min_amount, max_amount, currency, priority, is_active, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: fee_structures; Type: TABLE DATA; Schema: config; Owner: postgres
--

COPY config.fee_structures (id, name, description, fee_type, calculation_method, is_active, applies_to_all_transaction_types, applies_to_all_account_types, applies_to_all_currencies, min_fee_amount, max_fee_amount, fee_percentage, fixed_fee_amount, fee_currency, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: config; Owner: postgres
--

COPY config.settings (id, setting_key, setting_value, data_type, description, is_encrypted, is_sensitive, min_value, max_value, allowed_values, category, subcategory, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: account_balances; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_balances (id, account_id, balance_date, opening_balance, closing_balance, total_credits, total_debits, transaction_count, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: account_holders; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_holders (id, account_id, client_id, holder_type, added_date, removed_date, permissions, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: account_limits; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_limits (id, account_id, limit_type, currency_code, limit_value, period, effective_date, expiry_date, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: account_products; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_products (id, account_id, product_id, status, assigned_at, unassigned_at, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: account_types; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_types (id, type_code, name, description, features, restrictions, is_active, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.accounts (id, account_number, account_name, account_type_id, currency_code, current_balance, available_balance, hold_balance, status, open_date, last_activity_date, close_date, metadata, created_at, updated_at, created_by, updated_by, version, client_id) FROM stdin;
\.


--
-- Data for Name: addresses; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.addresses (id, address_type, line1, line2, city, state, postal_code, country_code, latitude, longitude, is_primary, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: branches; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.branches (id, branch_name, branch_code, address, city, state, postal_code, country_code, phone, email, is_active, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: client_profile_logs; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.client_profile_logs (id, client_id, changed_by, change_type, old_values, new_values, changed_at, reason, version) FROM stdin;
\.


--
-- Data for Name: client_versions; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.client_versions (version_id, client_id, version, data, modified_by, modified_at, reason_for_change) FROM stdin;
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.clients (id, client_number, client_type, status, title, first_name, middle_name, last_name, date_of_birth, gender, marital_status, email, email_verified, phone, phone_verified, occupation, employer_name, employment_status, annual_income, kyc_status, kyc_verified_at, kyc_verified_by, risk_level, relationship_manager_id, referral_source, created_at, updated_at, deleted_at, created_by, updated_by, version, branch_id) FROM stdin;
\.


--
-- Data for Name: custom_field_values; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.custom_field_values (id, entity_type, entity_id, field_id, field_name, value, data_type, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: custom_fields; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.custom_fields (id, entity_type, field_name, label, data_type, is_required, options, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: documents; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.documents (id, owner_type, owner_id, document_type, file_name, file_url, mime_type, status, metadata, uploaded_by, uploaded_at, created_at, updated_at, version) FROM stdin;
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.messages (id, sender_type, sender_id, recipient_type, recipient_id, message_type, subject, body, status, direction, metadata, sent_at, read_at, created_at, updated_at, version) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.notifications (id, recipient_type, recipient_id, notification_type, title, message, status, priority, metadata, sent_at, read_at, created_at, updated_at, version) FROM stdin;
\.


--
-- Data for Name: product_features; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.product_features (id, product_id, feature_name, feature_value, data_type, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.products (id, product_code, name, description, product_type, status, features, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: transaction_limits; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.transaction_limits (id, transaction_type_id, client_id, account_id, limit_type, currency_code, limit_value, period, effective_date, expiry_date, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: transaction_types; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.transaction_types (id, code, name, description, direction, affects_balance, requires_approval, approval_threshold, is_active, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.transactions (id, transaction_reference, transaction_type_id, status, amount, currency_code, exchange_rate, fee_amount, tax_amount, net_amount, transaction_date, value_date, parent_transaction_id, related_transaction_id, branch_id, teller_id, description, notes, metadata, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: user_limits; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.user_limits (id, user_id, limit_type, currency_code, limit_value, period, effective_date, expiry_date, status, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: goose_db_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.goose_db_version (id, version_id, is_applied, tstamp) FROM stdin;
1	0	t	2025-06-22 11:06:52.610089
2	1	t	2025-06-22 11:06:52.625982
3	2	t	2025-06-22 11:06:52.763462
4	3	t	2025-06-22 11:06:52.94587
5	4	t	2025-06-22 11:06:52.948396
6	5	t	2025-06-22 11:06:52.950238
7	6	t	2025-06-22 11:06:52.952414
8	7	t	2025-06-22 11:06:52.954102
9	8	t	2025-06-22 11:06:52.956516
10	9	t	2025-06-22 11:06:52.95856
11	10	t	2025-06-22 11:06:52.96039
12	11	t	2025-06-22 11:06:52.96228
13	12	t	2025-06-22 11:06:52.964222
14	13	t	2025-06-22 11:06:52.98205
15	14	t	2025-06-22 11:06:52.997084
16	15	t	2025-06-22 11:06:53.003114
17	16	t	2025-06-22 11:06:53.006503
18	17	t	2025-06-22 11:06:53.010089
19	18	t	2025-06-22 11:06:53.01217
20	19	t	2025-06-22 11:06:53.014521
21	20	t	2025-06-22 11:06:53.016618
22	21	t	2025-06-22 11:06:53.018492
23	22	t	2025-06-22 11:06:53.020117
24	23	t	2025-06-22 11:06:53.02173
25	24	t	2025-06-22 11:06:53.027368
26	25	t	2025-06-22 11:06:53.031562
27	26	t	2025-06-22 11:06:53.035901
28	27	t	2025-06-22 11:06:53.037955
29	28	t	2025-06-22 11:06:53.041174
30	29	t	2025-06-22 11:06:53.042769
31	30	t	2025-06-22 11:06:53.04391
32	31	t	2025-06-22 11:06:53.048845
33	32	t	2025-06-22 11:06:53.05035
34	33	t	2025-06-22 11:06:53.055847
35	34	t	2025-06-22 11:06:53.058442
36	35	t	2025-06-22 11:06:53.060391
37	36	t	2025-06-22 11:06:53.064407
38	37	t	2025-06-22 11:06:53.068534
39	38	t	2025-06-22 11:06:53.070165
40	39	t	2025-06-22 11:06:53.071535
41	40	t	2025-06-22 11:06:53.075453
42	41	t	2025-06-22 11:06:53.077094
43	42	t	2025-06-22 11:06:53.083467
44	43	t	2025-06-22 11:06:53.085206
45	44	t	2025-06-22 11:06:53.092826
46	45	t	2025-06-22 11:06:53.11057
47	46	t	2025-06-22 11:06:53.120775
48	47	t	2025-06-22 11:06:53.131613
49	48	t	2025-06-22 11:06:53.142272
50	49	t	2025-06-22 11:06:53.153293
51	50	t	2025-06-22 11:06:53.163435
52	51	t	2025-06-22 11:06:53.171422
53	52	t	2025-06-22 11:06:53.17958
54	53	t	2025-06-22 11:06:53.188454
55	54	t	2025-06-22 11:06:53.196429
56	55	t	2025-06-22 11:06:53.204005
57	56	t	2025-06-22 11:06:53.211836
58	57	t	2025-06-22 11:06:53.221006
59	58	t	2025-06-22 11:06:53.227868
60	59	t	2025-06-22 11:06:53.23734
61	60	t	2025-06-22 11:06:53.245916
62	61	t	2025-06-22 11:06:53.254466
63	62	t	2025-06-22 11:06:53.262925
64	63	t	2025-06-22 11:06:53.270995
65	64	t	2025-06-22 11:06:53.278912
66	65	t	2025-06-22 11:06:53.287525
67	66	t	2025-06-22 11:06:53.30721
68	67	t	2025-06-22 11:06:53.356053
69	68	t	2025-06-22 11:06:53.364136
70	69	t	2025-06-22 11:06:53.372139
\.


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.permissions_id_seq', 1, false);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.roles_id_seq', 1, false);


--
-- Name: blacklist_hits_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.blacklist_hits_id_seq', 1, false);


--
-- Name: case_attachments_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.case_attachments_id_seq', 1, false);


--
-- Name: case_audit_log_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.case_audit_log_id_seq', 1, false);


--
-- Name: case_management_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.case_management_id_seq', 1, false);


--
-- Name: case_notes_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.case_notes_id_seq', 1, false);


--
-- Name: pep_screenings_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.pep_screenings_id_seq', 1, false);


--
-- Name: risk_assessments_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.risk_assessments_id_seq', 1, false);


--
-- Name: sanctions_matches_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.sanctions_matches_id_seq', 1, false);


--
-- Name: watchlist_hits_id_seq; Type: SEQUENCE SET; Schema: compliance; Owner: postgres
--

SELECT pg_catalog.setval('compliance.watchlist_hits_id_seq', 1, false);


--
-- Name: goose_db_version_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.goose_db_version_id_seq', 70, true);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_code_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.permissions
    ADD CONSTRAINT permissions_code_key UNIQUE (code);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: user_activity_log user_activity_log_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_activity_log
    ADD CONSTRAINT user_activity_log_pkey PRIMARY KEY (id);


--
-- Name: user_invitations user_invitations_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_invitations
    ADD CONSTRAINT user_invitations_pkey PRIMARY KEY (id);


--
-- Name: user_invitations user_invitations_token_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_invitations
    ADD CONSTRAINT user_invitations_token_key UNIQUE (token);


--
-- Name: user_password_history user_password_history_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_password_history
    ADD CONSTRAINT user_password_history_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_refresh_token_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_sessions
    ADD CONSTRAINT user_sessions_refresh_token_key UNIQUE (refresh_token);


--
-- Name: user_sessions user_sessions_session_token_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_sessions
    ADD CONSTRAINT user_sessions_session_token_key UNIQUE (session_token);


--
-- Name: user_verification_tokens user_verification_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_verification_tokens
    ADD CONSTRAINT user_verification_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_verification_tokens user_verification_tokens_token_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_verification_tokens
    ADD CONSTRAINT user_verification_tokens_token_key UNIQUE (token);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_employee_id_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_employee_id_key UNIQUE (employee_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: aml_checks aml_checks_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.aml_checks
    ADD CONSTRAINT aml_checks_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: blacklist_hits blacklist_hits_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.blacklist_hits
    ADD CONSTRAINT blacklist_hits_pkey PRIMARY KEY (id);


--
-- Name: case_attachments case_attachments_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_attachments
    ADD CONSTRAINT case_attachments_pkey PRIMARY KEY (id);


--
-- Name: case_audit_log case_audit_log_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_audit_log
    ADD CONSTRAINT case_audit_log_pkey PRIMARY KEY (id);


--
-- Name: case_management case_management_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_management
    ADD CONSTRAINT case_management_pkey PRIMARY KEY (id);


--
-- Name: case_notes case_notes_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_notes
    ADD CONSTRAINT case_notes_pkey PRIMARY KEY (id);


--
-- Name: kyc_verifications kyc_verifications_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.kyc_verifications
    ADD CONSTRAINT kyc_verifications_pkey PRIMARY KEY (id);


--
-- Name: pep_screenings pep_screenings_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.pep_screenings
    ADD CONSTRAINT pep_screenings_pkey PRIMARY KEY (id);


--
-- Name: risk_assessments risk_assessments_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.risk_assessments
    ADD CONSTRAINT risk_assessments_pkey PRIMARY KEY (id);


--
-- Name: sanctions_matches sanctions_matches_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT sanctions_matches_pkey PRIMARY KEY (id);


--
-- Name: watchlist_hits watchlist_hits_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.watchlist_hits
    ADD CONSTRAINT watchlist_hits_pkey PRIMARY KEY (id);


--
-- Name: currencies currencies_pkey; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.currencies
    ADD CONSTRAINT currencies_pkey PRIMARY KEY (code);


--
-- Name: exchange_rates exchange_rates_pkey; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.exchange_rates
    ADD CONSTRAINT exchange_rates_pkey PRIMARY KEY (id);


--
-- Name: fee_structure_rules fee_structure_rules_pkey; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structure_rules
    ADD CONSTRAINT fee_structure_rules_pkey PRIMARY KEY (id);


--
-- Name: fee_structures fee_structures_pkey; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structures
    ADD CONSTRAINT fee_structures_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: exchange_rates uq_currency_pair_date; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.exchange_rates
    ADD CONSTRAINT uq_currency_pair_date UNIQUE (from_currency, to_currency, effective_date);


--
-- Name: fee_structures uq_fee_structures_name; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structures
    ADD CONSTRAINT uq_fee_structures_name UNIQUE (name);


--
-- Name: settings uq_setting_key; Type: CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.settings
    ADD CONSTRAINT uq_setting_key UNIQUE (setting_key);


--
-- Name: account_balances account_balances_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_balances
    ADD CONSTRAINT account_balances_pkey PRIMARY KEY (id);


--
-- Name: account_holders account_holders_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_holders
    ADD CONSTRAINT account_holders_pkey PRIMARY KEY (id);


--
-- Name: account_limits account_limits_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_limits
    ADD CONSTRAINT account_limits_pkey PRIMARY KEY (id);


--
-- Name: account_products account_products_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_products
    ADD CONSTRAINT account_products_pkey PRIMARY KEY (id);


--
-- Name: account_types account_types_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_types
    ADD CONSTRAINT account_types_pkey PRIMARY KEY (id);


--
-- Name: account_types account_types_type_code_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_types
    ADD CONSTRAINT account_types_type_code_key UNIQUE (type_code);


--
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: branches branches_branch_code_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.branches
    ADD CONSTRAINT branches_branch_code_key UNIQUE (branch_code);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: client_profile_logs client_profile_logs_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.client_profile_logs
    ADD CONSTRAINT client_profile_logs_pkey PRIMARY KEY (id);


--
-- Name: client_versions client_versions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.client_versions
    ADD CONSTRAINT client_versions_pkey PRIMARY KEY (version_id);


--
-- Name: clients clients_client_number_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.clients
    ADD CONSTRAINT clients_client_number_key UNIQUE (client_number);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: custom_field_values custom_field_values_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.custom_field_values
    ADD CONSTRAINT custom_field_values_pkey PRIMARY KEY (id);


--
-- Name: custom_fields custom_fields_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.custom_fields
    ADD CONSTRAINT custom_fields_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: product_features product_features_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.product_features
    ADD CONSTRAINT product_features_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: products products_product_code_key; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.products
    ADD CONSTRAINT products_product_code_key UNIQUE (product_code);


--
-- Name: transaction_limits transaction_limits_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_limits
    ADD CONSTRAINT transaction_limits_pkey PRIMARY KEY (id);


--
-- Name: transaction_types transaction_types_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_types
    ADD CONSTRAINT transaction_types_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: account_holders uq_account_holder; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_holders
    ADD CONSTRAINT uq_account_holder UNIQUE (account_id, client_id, holder_type);


--
-- Name: account_products uq_account_product; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_products
    ADD CONSTRAINT uq_account_product UNIQUE (account_id, product_id);


--
-- Name: custom_fields uq_custom_field; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.custom_fields
    ADD CONSTRAINT uq_custom_field UNIQUE (entity_type, field_name);


--
-- Name: custom_field_values uq_custom_field_value; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.custom_field_values
    ADD CONSTRAINT uq_custom_field_value UNIQUE (entity_type, entity_id, field_id);


--
-- Name: account_balances uq_daily_balance; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_balances
    ADD CONSTRAINT uq_daily_balance UNIQUE (account_id, balance_date);


--
-- Name: product_features uq_product_feature; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.product_features
    ADD CONSTRAINT uq_product_feature UNIQUE (product_id, feature_name);


--
-- Name: transaction_types uq_transaction_types_code; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_types
    ADD CONSTRAINT uq_transaction_types_code UNIQUE (code);


--
-- Name: transactions uq_transactions_reference; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transactions
    ADD CONSTRAINT uq_transactions_reference UNIQUE (transaction_reference);


--
-- Name: user_limits user_limits_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.user_limits
    ADD CONSTRAINT user_limits_pkey PRIMARY KEY (id);


--
-- Name: goose_db_version goose_db_version_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goose_db_version
    ADD CONSTRAINT goose_db_version_pkey PRIMARY KEY (id);


--
-- Name: idx_aml_check_status; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_check_status ON compliance.aml_checks USING btree (check_status);


--
-- Name: idx_aml_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_client_id ON compliance.aml_checks USING btree (client_id);


--
-- Name: idx_aml_created_at_desc; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_created_at_desc ON compliance.aml_checks USING btree (created_at DESC);


--
-- Name: idx_aml_created_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_created_by ON compliance.aml_checks USING btree (created_by);


--
-- Name: idx_aml_risk_level; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_risk_level ON compliance.aml_checks USING btree (risk_level);


--
-- Name: idx_aml_status_risk_level; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_status_risk_level ON compliance.aml_checks USING btree (check_status, risk_level);


--
-- Name: idx_aml_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_transaction_id ON compliance.aml_checks USING btree (transaction_id);


--
-- Name: idx_aml_updated_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_aml_updated_by ON compliance.aml_checks USING btree (updated_by);


--
-- Name: idx_audit_logs_action; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_action ON compliance.audit_logs USING btree (action);


--
-- Name: idx_audit_logs_event_time_desc; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_event_time_desc ON compliance.audit_logs USING btree (event_time DESC);


--
-- Name: idx_audit_logs_record_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_record_id ON compliance.audit_logs USING btree (record_id);


--
-- Name: idx_audit_logs_table_name; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_table_name ON compliance.audit_logs USING btree (table_name);


--
-- Name: idx_audit_logs_table_record; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_table_record ON compliance.audit_logs USING btree (table_name, record_id);


--
-- Name: idx_audit_logs_user_event_time; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_user_event_time ON compliance.audit_logs USING btree (user_id, event_time DESC);


--
-- Name: idx_audit_logs_user_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_user_id ON compliance.audit_logs USING btree (user_id);


--
-- Name: idx_blacklist_hits_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_blacklist_hits_client_id ON compliance.blacklist_hits USING btree (client_id);


--
-- Name: idx_blacklist_hits_resolved; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_blacklist_hits_resolved ON compliance.blacklist_hits USING btree (resolved);


--
-- Name: idx_blacklist_hits_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_blacklist_hits_transaction_id ON compliance.blacklist_hits USING btree (transaction_id);


--
-- Name: idx_case_attachments_case_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_attachments_case_id ON compliance.case_attachments USING btree (case_id);


--
-- Name: idx_case_attachments_uploaded_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_attachments_uploaded_by ON compliance.case_attachments USING btree (uploaded_by);


--
-- Name: idx_case_audit_log_case_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_audit_log_case_id ON compliance.case_audit_log USING btree (case_id);


--
-- Name: idx_case_audit_log_created_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_audit_log_created_by ON compliance.case_audit_log USING btree (created_by);


--
-- Name: idx_case_audit_log_event_type; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_audit_log_event_type ON compliance.case_audit_log USING btree (event_type);


--
-- Name: idx_case_management_assigned_to; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_management_assigned_to ON compliance.case_management USING btree (assigned_to);


--
-- Name: idx_case_management_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_management_client_id ON compliance.case_management USING btree (client_id);


--
-- Name: idx_case_management_status; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_management_status ON compliance.case_management USING btree (status);


--
-- Name: idx_case_notes_case_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_notes_case_id ON compliance.case_notes USING btree (case_id);


--
-- Name: idx_case_notes_created_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_case_notes_created_by ON compliance.case_notes USING btree (created_by);


--
-- Name: idx_kyc_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_client_id ON compliance.kyc_verifications USING btree (client_id);


--
-- Name: idx_kyc_created_at_desc; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_created_at_desc ON compliance.kyc_verifications USING btree (created_at DESC);


--
-- Name: idx_kyc_created_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_created_by ON compliance.kyc_verifications USING btree (created_by);


--
-- Name: idx_kyc_status; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_status ON compliance.kyc_verifications USING btree (verification_status);


--
-- Name: idx_kyc_status_verified_at; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_status_verified_at ON compliance.kyc_verifications USING btree (verification_status, verified_at DESC);


--
-- Name: idx_kyc_updated_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_updated_by ON compliance.kyc_verifications USING btree (updated_by);


--
-- Name: idx_kyc_verified_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_kyc_verified_by ON compliance.kyc_verifications USING btree (verified_by);


--
-- Name: idx_pep_screenings_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_pep_screenings_client_id ON compliance.pep_screenings USING btree (client_id);


--
-- Name: idx_pep_screenings_resolved; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_pep_screenings_resolved ON compliance.pep_screenings USING btree (resolved);


--
-- Name: idx_pep_screenings_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_pep_screenings_transaction_id ON compliance.pep_screenings USING btree (transaction_id);


--
-- Name: idx_risk_assessments_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_risk_assessments_client_id ON compliance.risk_assessments USING btree (client_id);


--
-- Name: idx_risk_assessments_risk_level; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_risk_assessments_risk_level ON compliance.risk_assessments USING btree (risk_level);


--
-- Name: idx_risk_assessments_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_risk_assessments_transaction_id ON compliance.risk_assessments USING btree (transaction_id);


--
-- Name: idx_sanctions_matches_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_client_id ON compliance.sanctions_matches USING btree (client_id);


--
-- Name: idx_sanctions_matches_created_at_desc; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_created_at_desc ON compliance.sanctions_matches USING btree (created_at DESC);


--
-- Name: idx_sanctions_matches_resolved; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_resolved ON compliance.sanctions_matches USING btree (resolved);


--
-- Name: idx_sanctions_matches_resolved_by; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_resolved_by ON compliance.sanctions_matches USING btree (resolved_by);


--
-- Name: idx_sanctions_matches_resolved_date; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_resolved_date ON compliance.sanctions_matches USING btree (resolved, match_date DESC);


--
-- Name: idx_sanctions_matches_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_sanctions_matches_transaction_id ON compliance.sanctions_matches USING btree (transaction_id);


--
-- Name: idx_watchlist_hits_client_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_watchlist_hits_client_id ON compliance.watchlist_hits USING btree (client_id);


--
-- Name: idx_watchlist_hits_resolved; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_watchlist_hits_resolved ON compliance.watchlist_hits USING btree (resolved);


--
-- Name: idx_watchlist_hits_transaction_id; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_watchlist_hits_transaction_id ON compliance.watchlist_hits USING btree (transaction_id);


--
-- Name: idx_account_balances_account_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_account_id ON core.account_balances USING btree (account_id);


--
-- Name: idx_account_balances_balance_date_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_balance_date_desc ON core.account_balances USING btree (balance_date DESC);


--
-- Name: idx_account_balances_created_at_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_created_at_desc ON core.account_balances USING btree (created_at DESC);


--
-- Name: idx_account_balances_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_created_by ON core.account_balances USING btree (created_by);


--
-- Name: idx_account_balances_updated_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_updated_by ON core.account_balances USING btree (updated_by);


--
-- Name: idx_account_holders_account_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_account_id ON core.account_holders USING btree (account_id);


--
-- Name: idx_account_holders_client_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_client_id ON core.account_holders USING btree (client_id);


--
-- Name: idx_account_holders_created_at_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_created_at_desc ON core.account_holders USING btree (created_at DESC);


--
-- Name: idx_account_holders_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_created_by ON core.account_holders USING btree (created_by);


--
-- Name: idx_account_holders_holder_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_holder_type ON core.account_holders USING btree (holder_type);


--
-- Name: idx_account_holders_updated_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_updated_by ON core.account_holders USING btree (updated_by);


--
-- Name: idx_account_limits_account_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_limits_account_id ON core.account_limits USING btree (account_id);


--
-- Name: idx_account_limits_limit_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_limits_limit_type ON core.account_limits USING btree (limit_type);


--
-- Name: idx_account_limits_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_limits_status ON core.account_limits USING btree (status);


--
-- Name: idx_account_products_account_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_products_account_id ON core.account_products USING btree (account_id);


--
-- Name: idx_account_products_product_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_products_product_id ON core.account_products USING btree (product_id);


--
-- Name: idx_account_products_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_products_status ON core.account_products USING btree (status);


--
-- Name: idx_accounts_account_type_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_account_type_id ON core.accounts USING btree (account_type_id);


--
-- Name: idx_accounts_client_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_client_id ON core.accounts USING btree (client_id);


--
-- Name: idx_accounts_created_at_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_created_at_desc ON core.accounts USING btree (created_at DESC);


--
-- Name: idx_accounts_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_created_by ON core.accounts USING btree (created_by);


--
-- Name: idx_accounts_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_status ON core.accounts USING btree (status);


--
-- Name: idx_accounts_status_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_status_type ON core.accounts USING btree (status, account_type_id);


--
-- Name: idx_accounts_updated_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_updated_by ON core.accounts USING btree (updated_by);


--
-- Name: idx_addresses_city; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_addresses_city ON core.addresses USING btree (city);


--
-- Name: idx_addresses_country_code; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_addresses_country_code ON core.addresses USING btree (country_code);


--
-- Name: idx_addresses_postal_code; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_addresses_postal_code ON core.addresses USING btree (postal_code);


--
-- Name: idx_clients_branch_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_branch_id ON core.clients USING btree (branch_id);


--
-- Name: idx_clients_created_at_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_created_at_desc ON core.clients USING btree (created_at DESC);


--
-- Name: idx_clients_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_created_by ON core.clients USING btree (created_by);


--
-- Name: idx_clients_kyc_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_kyc_status ON core.clients USING btree (kyc_status);


--
-- Name: idx_clients_relationship_manager_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_relationship_manager_id ON core.clients USING btree (relationship_manager_id);


--
-- Name: idx_clients_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_status ON core.clients USING btree (status);


--
-- Name: idx_clients_updated_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_updated_by ON core.clients USING btree (updated_by);


--
-- Name: idx_custom_field_values_entity; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_custom_field_values_entity ON core.custom_field_values USING btree (entity_type, entity_id);


--
-- Name: idx_custom_field_values_field_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_custom_field_values_field_id ON core.custom_field_values USING btree (field_id);


--
-- Name: idx_custom_field_values_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_custom_field_values_status ON core.custom_field_values USING btree (status);


--
-- Name: idx_custom_fields_entity_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_custom_fields_entity_type ON core.custom_fields USING btree (entity_type);


--
-- Name: idx_custom_fields_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_custom_fields_status ON core.custom_fields USING btree (status);


--
-- Name: idx_documents_document_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_documents_document_type ON core.documents USING btree (document_type);


--
-- Name: idx_documents_owner_type_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_documents_owner_type_id ON core.documents USING btree (owner_type, owner_id);


--
-- Name: idx_documents_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_documents_status ON core.documents USING btree (status);


--
-- Name: idx_messages_recipient; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_messages_recipient ON core.messages USING btree (recipient_type, recipient_id);


--
-- Name: idx_messages_sender; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_messages_sender ON core.messages USING btree (sender_type, sender_id);


--
-- Name: idx_messages_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_messages_status ON core.messages USING btree (status);


--
-- Name: idx_messages_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_messages_type ON core.messages USING btree (message_type);


--
-- Name: idx_notifications_recipient; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_notifications_recipient ON core.notifications USING btree (recipient_type, recipient_id);


--
-- Name: idx_notifications_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_notifications_status ON core.notifications USING btree (status);


--
-- Name: idx_notifications_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_notifications_type ON core.notifications USING btree (notification_type);


--
-- Name: idx_product_features_product_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_product_features_product_id ON core.product_features USING btree (product_id);


--
-- Name: idx_product_features_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_product_features_status ON core.product_features USING btree (status);


--
-- Name: idx_products_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_products_status ON core.products USING btree (status);


--
-- Name: idx_products_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_products_type ON core.products USING btree (product_type);


--
-- Name: idx_transaction_limits_account_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transaction_limits_account_id ON core.transaction_limits USING btree (account_id);


--
-- Name: idx_transaction_limits_client_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transaction_limits_client_id ON core.transaction_limits USING btree (client_id);


--
-- Name: idx_transaction_limits_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transaction_limits_status ON core.transaction_limits USING btree (status);


--
-- Name: idx_transaction_limits_transaction_type_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transaction_limits_transaction_type_id ON core.transaction_limits USING btree (transaction_type_id);


--
-- Name: idx_transaction_limits_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transaction_limits_type ON core.transaction_limits USING btree (limit_type);


--
-- Name: idx_transactions_branch_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_branch_id ON core.transactions USING btree (branch_id);


--
-- Name: idx_transactions_branch_id_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_branch_id_transaction_date ON core.transactions USING btree (branch_id, transaction_date DESC);


--
-- Name: idx_transactions_created_at_desc; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_created_at_desc ON core.transactions USING btree (created_at DESC);


--
-- Name: idx_transactions_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_created_by ON core.transactions USING btree (created_by);


--
-- Name: idx_transactions_parent_transaction_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_parent_transaction_id ON core.transactions USING btree (parent_transaction_id);


--
-- Name: idx_transactions_pending_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_pending_status ON core.transactions USING btree (status) WHERE (status = 'pending'::public.transaction_status);


--
-- Name: idx_transactions_related_transaction_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_related_transaction_id ON core.transactions USING btree (related_transaction_id);


--
-- Name: idx_transactions_status_branch_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_status_branch_transaction_date ON core.transactions USING btree (status, branch_id, transaction_date DESC);


--
-- Name: idx_transactions_status_teller_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_status_teller_transaction_date ON core.transactions USING btree (status, teller_id, transaction_date DESC);


--
-- Name: idx_transactions_status_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_status_transaction_date ON core.transactions USING btree (status, transaction_date DESC);


--
-- Name: idx_transactions_teller_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_teller_id ON core.transactions USING btree (teller_id);


--
-- Name: idx_transactions_teller_id_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_teller_id_transaction_date ON core.transactions USING btree (teller_id, transaction_date DESC);


--
-- Name: idx_transactions_transaction_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_transaction_date ON core.transactions USING btree (transaction_date);


--
-- Name: idx_transactions_transaction_type_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_transaction_type_id ON core.transactions USING btree (transaction_type_id);


--
-- Name: idx_transactions_updated_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_updated_by ON core.transactions USING btree (updated_by);


--
-- Name: idx_user_limits_limit_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_user_limits_limit_type ON core.user_limits USING btree (limit_type);


--
-- Name: idx_user_limits_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_user_limits_status ON core.user_limits USING btree (status);


--
-- Name: idx_user_limits_user_id; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_user_limits_user_id ON core.user_limits USING btree (user_id);


--
-- Name: users fk_users_branch; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT fk_users_branch FOREIGN KEY (branch_id) REFERENCES core.branches(id);


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES auth.roles(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_activity_log user_activity_log_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_activity_log
    ADD CONSTRAINT user_activity_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_invitations user_invitations_accepted_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_invitations
    ADD CONSTRAINT user_invitations_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES auth.users(id);


--
-- Name: user_invitations user_invitations_invited_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_invitations
    ADD CONSTRAINT user_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id);


--
-- Name: user_invitations user_invitations_role_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_invitations
    ADD CONSTRAINT user_invitations_role_id_fkey FOREIGN KEY (role_id) REFERENCES auth.roles(id);


--
-- Name: user_password_history user_password_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_password_history
    ADD CONSTRAINT user_password_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id);


--
-- Name: user_password_history user_password_history_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_password_history
    ADD CONSTRAINT user_password_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_created_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_roles
    ADD CONSTRAINT user_roles_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES auth.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_verification_tokens user_verification_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_verification_tokens
    ADD CONSTRAINT user_verification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: users users_deleted_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES auth.users(id);


--
-- Name: users users_invited_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id);


--
-- Name: users users_manager_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES auth.users(id);


--
-- Name: users users_status_changed_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_status_changed_by_fkey FOREIGN KEY (status_changed_by) REFERENCES auth.users(id);


--
-- Name: users users_updated_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id);


--
-- Name: blacklist_hits blacklist_hits_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.blacklist_hits
    ADD CONSTRAINT blacklist_hits_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: blacklist_hits blacklist_hits_resolved_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.blacklist_hits
    ADD CONSTRAINT blacklist_hits_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id);


--
-- Name: blacklist_hits blacklist_hits_transaction_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.blacklist_hits
    ADD CONSTRAINT blacklist_hits_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE CASCADE;


--
-- Name: case_attachments case_attachments_case_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_attachments
    ADD CONSTRAINT case_attachments_case_id_fkey FOREIGN KEY (case_id) REFERENCES compliance.case_management(id) ON DELETE CASCADE;


--
-- Name: case_attachments case_attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_attachments
    ADD CONSTRAINT case_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id);


--
-- Name: case_audit_log case_audit_log_case_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_audit_log
    ADD CONSTRAINT case_audit_log_case_id_fkey FOREIGN KEY (case_id) REFERENCES compliance.case_management(id) ON DELETE CASCADE;


--
-- Name: case_audit_log case_audit_log_created_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_audit_log
    ADD CONSTRAINT case_audit_log_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: case_management case_management_assigned_to_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_management
    ADD CONSTRAINT case_management_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id);


--
-- Name: case_management case_management_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_management
    ADD CONSTRAINT case_management_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: case_notes case_notes_case_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_notes
    ADD CONSTRAINT case_notes_case_id_fkey FOREIGN KEY (case_id) REFERENCES compliance.case_management(id) ON DELETE CASCADE;


--
-- Name: case_notes case_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.case_notes
    ADD CONSTRAINT case_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: aml_checks fk_aml_client; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.aml_checks
    ADD CONSTRAINT fk_aml_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE SET NULL;


--
-- Name: aml_checks fk_aml_transaction; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.aml_checks
    ADD CONSTRAINT fk_aml_transaction FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE SET NULL;


--
-- Name: kyc_verifications fk_kyc_client; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.kyc_verifications
    ADD CONSTRAINT fk_kyc_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: pep_screenings pep_screenings_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.pep_screenings
    ADD CONSTRAINT pep_screenings_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: pep_screenings pep_screenings_resolved_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.pep_screenings
    ADD CONSTRAINT pep_screenings_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id);


--
-- Name: pep_screenings pep_screenings_transaction_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.pep_screenings
    ADD CONSTRAINT pep_screenings_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE CASCADE;


--
-- Name: risk_assessments risk_assessments_assessed_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.risk_assessments
    ADD CONSTRAINT risk_assessments_assessed_by_fkey FOREIGN KEY (assessed_by) REFERENCES auth.users(id);


--
-- Name: risk_assessments risk_assessments_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.risk_assessments
    ADD CONSTRAINT risk_assessments_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: risk_assessments risk_assessments_transaction_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.risk_assessments
    ADD CONSTRAINT risk_assessments_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE CASCADE;


--
-- Name: sanctions_matches sanctions_matches_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT sanctions_matches_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: sanctions_matches sanctions_matches_resolved_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT sanctions_matches_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id);


--
-- Name: sanctions_matches sanctions_matches_transaction_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT sanctions_matches_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE CASCADE;


--
-- Name: watchlist_hits watchlist_hits_client_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.watchlist_hits
    ADD CONSTRAINT watchlist_hits_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: watchlist_hits watchlist_hits_resolved_by_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.watchlist_hits
    ADD CONSTRAINT watchlist_hits_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id);


--
-- Name: watchlist_hits watchlist_hits_transaction_id_fkey; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.watchlist_hits
    ADD CONSTRAINT watchlist_hits_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE CASCADE;


--
-- Name: fee_structure_rules fk_currency; Type: FK CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structure_rules
    ADD CONSTRAINT fk_currency FOREIGN KEY (currency) REFERENCES config.currencies(code) ON DELETE SET NULL;


--
-- Name: fee_structures fk_fee_currency; Type: FK CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structures
    ADD CONSTRAINT fk_fee_currency FOREIGN KEY (fee_currency) REFERENCES config.currencies(code) ON DELETE SET NULL;


--
-- Name: fee_structure_rules fk_fee_structure; Type: FK CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.fee_structure_rules
    ADD CONSTRAINT fk_fee_structure FOREIGN KEY (fee_structure_id) REFERENCES config.fee_structures(id) ON DELETE CASCADE;


--
-- Name: exchange_rates fk_from_currency; Type: FK CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.exchange_rates
    ADD CONSTRAINT fk_from_currency FOREIGN KEY (from_currency) REFERENCES config.currencies(code) ON DELETE CASCADE;


--
-- Name: exchange_rates fk_to_currency; Type: FK CONSTRAINT; Schema: config; Owner: postgres
--

ALTER TABLE ONLY config.exchange_rates
    ADD CONSTRAINT fk_to_currency FOREIGN KEY (to_currency) REFERENCES config.currencies(code) ON DELETE CASCADE;


--
-- Name: account_balances fk_account_balances_account; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_balances
    ADD CONSTRAINT fk_account_balances_account FOREIGN KEY (account_id) REFERENCES core.accounts(id);


--
-- Name: account_limits fk_account_limits_account; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_limits
    ADD CONSTRAINT fk_account_limits_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;


--
-- Name: account_products fk_account_products_account; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_products
    ADD CONSTRAINT fk_account_products_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;


--
-- Name: account_products fk_account_products_product; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_products
    ADD CONSTRAINT fk_account_products_product FOREIGN KEY (product_id) REFERENCES core.products(id) ON DELETE CASCADE;


--
-- Name: accounts fk_accounts_account_type; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT fk_accounts_account_type FOREIGN KEY (account_type_id) REFERENCES core.account_types(id);


--
-- Name: accounts fk_accounts_client; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT fk_accounts_client FOREIGN KEY (client_id) REFERENCES core.clients(id);


--
-- Name: clients fk_clients_branch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.clients
    ADD CONSTRAINT fk_clients_branch FOREIGN KEY (branch_id) REFERENCES core.branches(id);


--
-- Name: custom_field_values fk_custom_field_values_field; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.custom_field_values
    ADD CONSTRAINT fk_custom_field_values_field FOREIGN KEY (field_id) REFERENCES core.custom_fields(id) ON DELETE CASCADE;


--
-- Name: product_features fk_product_features_product; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.product_features
    ADD CONSTRAINT fk_product_features_product FOREIGN KEY (product_id) REFERENCES core.products(id) ON DELETE CASCADE;


--
-- Name: transaction_limits fk_transaction_limits_account; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_limits
    ADD CONSTRAINT fk_transaction_limits_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;


--
-- Name: transaction_limits fk_transaction_limits_client; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_limits
    ADD CONSTRAINT fk_transaction_limits_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: transaction_limits fk_transaction_limits_type; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transaction_limits
    ADD CONSTRAINT fk_transaction_limits_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id) ON DELETE CASCADE;


--
-- Name: transactions fk_transactions_type; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transactions
    ADD CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id) ON DELETE RESTRICT;


--
-- Name: user_limits fk_user_limits_user; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.user_limits
    ADD CONSTRAINT fk_user_limits_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 14.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

