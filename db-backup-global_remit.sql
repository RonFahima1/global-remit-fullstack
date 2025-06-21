--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 14.18 (Homebrew)

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
    'DELETED'
);


ALTER TYPE public.user_status OWNER TO postgres;

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
    status character varying(20) DEFAULT 'PENDING_VERIFICATION'::character varying NOT NULL,
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
    must_change_password boolean DEFAULT false NOT NULL,
    CONSTRAINT users_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING_VERIFICATION'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'LOCKED'::character varying])::text[])))
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
-- Name: sanctions_matches; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.sanctions_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid,
    transaction_id uuid,
    list_name character varying(100) NOT NULL,
    matched_name text NOT NULL,
    match_score numeric(5,2) NOT NULL,
    match_data jsonb,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    reviewed_at timestamp with time zone,
    reviewed_by uuid,
    review_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT chk_sanctions_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'false_positive'::character varying, 'confirmed'::character varying, 'resolved'::character varying])::text[])))
);


ALTER TABLE compliance.sanctions_matches OWNER TO postgres;

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
    CONSTRAINT chk_removal_date CHECK (((removed_date IS NULL) OR ((removed_date IS NOT NULL) AND (removed_date >= added_date))))
);


ALTER TABLE core.account_holders OWNER TO postgres;

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
    CONSTRAINT accounts_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'DORMANT'::character varying, 'RESTRICTED'::character varying, 'CLOSED'::character varying])::text[]))),
    CONSTRAINT chk_available_balance CHECK ((available_balance <= current_balance)),
    CONSTRAINT chk_balance_non_negative CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT chk_dates CHECK (((close_date IS NULL) OR ((close_date IS NOT NULL) AND (close_date >= open_date)))),
    CONSTRAINT chk_hold_balance CHECK ((hold_balance <= current_balance))
);


ALTER TABLE core.accounts OWNER TO postgres;

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
    CONSTRAINT chk_phone_format CHECK (((phone IS NULL) OR ((phone)::text ~* '^\\+?[0-9\\s-]+$'::text))),
    CONSTRAINT clients_client_type_check CHECK (((client_type)::text = ANY ((ARRAY['INDIVIDUAL'::character varying, 'BUSINESS'::character varying, 'ORGANIZATION'::character varying])::text[]))),
    CONSTRAINT clients_gender_check CHECK (((gender)::text = ANY ((ARRAY['MALE'::character varying, 'FEMALE'::character varying, 'OTHER'::character varying, 'UNSPECIFIED'::character varying])::text[]))),
    CONSTRAINT clients_kyc_status_check CHECK (((kyc_status)::text = ANY ((ARRAY['NOT_VERIFIED'::character varying, 'PENDING'::character varying, 'VERIFIED'::character varying, 'REJECTED'::character varying, 'EXPIRED'::character varying])::text[]))),
    CONSTRAINT clients_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'CLOSED'::character varying, 'DECEASED'::character varying])::text[])))
);


ALTER TABLE core.clients OWNER TO postgres;

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
    CONSTRAINT chk_transaction_amount CHECK ((amount > (0)::numeric))
);


ALTER TABLE core.transactions OWNER TO postgres;

--
-- Name: permissions id; Type: DEFAULT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.permissions ALTER COLUMN id SET DEFAULT nextval('auth.permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.roles ALTER COLUMN id SET DEFAULT nextval('auth.roles_id_seq'::regclass);


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.password_reset_tokens (id, user_id, token_hash, expires_at, is_used, created_at) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.permissions (id, code, name, description, category, created_at) FROM stdin;
7	users:create	Create Users	Can create users	users	2025-06-21 21:58:43.581572+00
8	users:read	Read Users	Can view users	users	2025-06-21 21:58:43.581572+00
9	users:update	Update Users	Can update users	users	2025-06-21 21:58:43.581572+00
10	users:delete	Delete Users	Can delete users	users	2025-06-21 21:58:43.581572+00
11	roles:read	Read Roles	Can view roles	roles	2025-06-21 21:58:43.581572+00
12	roles:update	Update Roles	Can update roles	roles	2025-06-21 21:58:43.581572+00
13	settings:update	Update Settings	Can update settings	settings	2025-06-21 21:58:43.581572+00
14	audit:read	Read Audit Logs	Can view audit logs	audit	2025-06-21 21:58:43.581572+00
15	clients:create	Create Clients	Can create clients	clients	2025-06-21 21:58:43.581572+00
16	clients:read	Read Clients	Can view clients	clients	2025-06-21 21:58:43.581572+00
17	clients:update	Update Clients	Can update clients	clients	2025-06-21 21:58:43.581572+00
18	clients:delete	Delete Clients	Can delete clients	clients	2025-06-21 21:58:43.581572+00
19	transactions:create	Create Transactions	Can create transactions	transactions	2025-06-21 21:58:43.581572+00
20	transactions:read	Read Transactions	Can view transactions	transactions	2025-06-21 21:58:43.581572+00
21	transactions:update	Update Transactions	Can update transactions	transactions	2025-06-21 21:58:43.581572+00
22	transactions:delete	Delete Transactions	Can delete transactions	transactions	2025-06-21 21:58:43.581572+00
23	transactions:approve	Approve Transactions	Can approve transactions	transactions	2025-06-21 21:58:43.581572+00
24	kyc:approve	Approve KYC	Can approve KYC	kyc	2025-06-21 21:58:43.581572+00
25	reports:read	Read Reports	Can view reports	reports	2025-06-21 21:58:43.581572+00
26	profile:update	Update Profile	Can update own profile	profile	2025-06-21 21:58:43.581572+00
\.


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.role_permissions (role_id, permission_id, created_at) FROM stdin;
5	7	2025-06-21 21:58:43.585869+00
5	8	2025-06-21 21:58:43.585869+00
5	9	2025-06-21 21:58:43.585869+00
5	10	2025-06-21 21:58:43.585869+00
5	11	2025-06-21 21:58:43.585869+00
5	12	2025-06-21 21:58:43.585869+00
5	13	2025-06-21 21:58:43.585869+00
5	14	2025-06-21 21:58:43.585869+00
5	15	2025-06-21 21:58:43.585869+00
5	16	2025-06-21 21:58:43.585869+00
5	17	2025-06-21 21:58:43.585869+00
5	18	2025-06-21 21:58:43.585869+00
5	19	2025-06-21 21:58:43.585869+00
5	20	2025-06-21 21:58:43.585869+00
5	21	2025-06-21 21:58:43.585869+00
5	22	2025-06-21 21:58:43.585869+00
5	23	2025-06-21 21:58:43.585869+00
5	24	2025-06-21 21:58:43.585869+00
5	25	2025-06-21 21:58:43.585869+00
5	26	2025-06-21 21:58:43.585869+00
6	7	2025-06-21 21:58:43.588183+00
6	8	2025-06-21 21:58:43.588183+00
6	9	2025-06-21 21:58:43.588183+00
6	10	2025-06-21 21:58:43.588183+00
6	11	2025-06-21 21:58:43.588183+00
6	13	2025-06-21 21:58:43.588183+00
6	15	2025-06-21 21:58:43.588183+00
6	16	2025-06-21 21:58:43.588183+00
6	17	2025-06-21 21:58:43.588183+00
6	18	2025-06-21 21:58:43.588183+00
6	19	2025-06-21 21:58:43.588183+00
6	20	2025-06-21 21:58:43.588183+00
6	21	2025-06-21 21:58:43.588183+00
6	22	2025-06-21 21:58:43.588183+00
6	23	2025-06-21 21:58:43.588183+00
6	24	2025-06-21 21:58:43.588183+00
6	25	2025-06-21 21:58:43.588183+00
6	26	2025-06-21 21:58:43.588183+00
7	16	2025-06-21 21:58:43.589432+00
7	19	2025-06-21 21:58:43.589432+00
7	20	2025-06-21 21:58:43.589432+00
7	25	2025-06-21 21:58:43.589432+00
7	26	2025-06-21 21:58:43.589432+00
8	20	2025-06-21 21:58:43.590381+00
8	24	2025-06-21 21:58:43.590381+00
8	25	2025-06-21 21:58:43.590381+00
8	26	2025-06-21 21:58:43.590381+00
9	8	2025-06-21 21:58:43.590948+00
9	16	2025-06-21 21:58:43.590948+00
9	20	2025-06-21 21:58:43.590948+00
9	25	2025-06-21 21:58:43.590948+00
9	26	2025-06-21 21:58:43.590948+00
10	8	2025-06-21 21:58:43.591779+00
10	11	2025-06-21 21:58:43.591779+00
10	14	2025-06-21 21:58:43.591779+00
10	16	2025-06-21 21:58:43.591779+00
10	20	2025-06-21 21:58:43.591779+00
10	25	2025-06-21 21:58:43.591779+00
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.roles (id, name, description, is_system, created_at, updated_at) FROM stdin;
5	ORG_ADMIN	Full organization admin	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
6	AGENT_ADMIN	Manages agents and teller users	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
7	AGENT_USER	Teller: can process transactions	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
8	COMPLIANCE_USER	Handles compliance reviews, KYC	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
9	ORG_USER	Regular org user: limited access	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
10	GLOBAL_VIEWER	View everything, no changes	t	2025-06-21 21:58:43.579156+00	2025-06-21 21:58:43.579156+00
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.sessions (id, user_id, token_hash, user_agent, ip_address, expires_at, last_activity, is_revoked, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_roles (user_id, role_id, created_at, created_by) FROM stdin;
c35dc0a7-0162-4e03-b45d-de1891be382e	5	2025-06-21 21:58:55.135784+00	\N
08cb5c18-9aa8-406f-a69b-332c4f2206c9	6	2025-06-21 21:58:55.207635+00	\N
a48e9c32-e629-4fd4-83b8-afb18d5967d1	7	2025-06-21 21:59:08.999861+00	\N
38b35371-6116-47da-963a-d4922ab74e30	8	2025-06-21 21:59:09.002232+00	\N
42fbff15-7a1e-43dd-8dfd-cf7a0f7a9e92	9	2025-06-21 21:59:09.003887+00	\N
c8233572-ec80-481a-959a-e39b0da6b90f	5	2025-06-21 22:00:00.551312+00	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.users (id, username, email, email_verified, password_hash, password_changed_at, password_reset_token, password_reset_expires_at, mfa_enabled, mfa_secret, mfa_recovery_codes, status, failed_login_attempts, locked_until, first_name, last_name, phone, phone_verified, last_login_at, last_login_ip, last_login_user_agent, created_at, updated_at, deleted_at, version, must_change_password) FROM stdin;
c8233572-ec80-481a-959a-e39b0da6b90f	testuser	test@example.com	t	$2a$10$2GVZmzmTlFwRhMGt./gby.almTj9/tMMEJr6cwSZ4niLkdFfstUbi	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Test	User	\N	f	\N	\N	\N	2025-06-21 22:00:00.547031+00	2025-06-21 22:00:00.547031+00	\N	1	f
c35dc0a7-0162-4e03-b45d-de1891be382e	orgadmin@example.com	orgadmin@example.com	t	$2a$10$FP9KtbDKB7Hs8JZaO3veT.KomUVQW/3tzpqUupQtzcOujbp9fqCXO	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Org	Admin	\N	f	\N	\N	\N	2025-06-21 21:58:55.13206+00	2025-06-21 21:58:55.13206+00	\N	1	f
08cb5c18-9aa8-406f-a69b-332c4f2206c9	agentadmin@example.com	agentadmin@example.com	t	$2a$10$FP9KtbDKB7Hs8JZaO3veT.KomUVQW/3tzpqUupQtzcOujbp9fqCXO	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Agent	Admin	\N	f	\N	\N	\N	2025-06-21 21:58:55.205876+00	2025-06-21 21:58:55.205876+00	\N	1	f
a48e9c32-e629-4fd4-83b8-afb18d5967d1	agentuser	agentuser@example.com	t	$2a$10$FP9KtbDKB7Hs8JZaO3veT.KomUVQW/3tzpqUupQtzcOujbp9fqCXO	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Agent	User	\N	f	\N	\N	\N	2025-06-21 21:59:08.990098+00	2025-06-21 21:59:08.990098+00	\N	1	f
38b35371-6116-47da-963a-d4922ab74e30	complianceuser	complianceuser@example.com	t	$2a$10$FP9KtbDKB7Hs8JZaO3veT.KomUVQW/3tzpqUupQtzcOujbp9fqCXO	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Compliance	User	\N	f	\N	\N	\N	2025-06-21 21:59:08.991712+00	2025-06-21 21:59:08.991712+00	\N	1	f
42fbff15-7a1e-43dd-8dfd-cf7a0f7a9e92	orguser	orguser@example.com	t	$2a$10$FP9KtbDKB7Hs8JZaO3veT.KomUVQW/3tzpqUupQtzcOujbp9fqCXO	\N	\N	\N	f	\N	\N	ACTIVE	0	\N	Org	User	\N	f	\N	\N	\N	2025-06-21 21:59:08.993337+00	2025-06-21 21:59:08.993337+00	\N	1	f
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
-- Data for Name: kyc_verifications; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.kyc_verifications (id, client_id, verification_type, verification_status, verified_at, verified_by, expiration_date, verification_data, rejection_reason, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: sanctions_matches; Type: TABLE DATA; Schema: compliance; Owner: postgres
--

COPY compliance.sanctions_matches (id, client_id, transaction_id, list_name, matched_name, match_score, match_data, status, reviewed_at, reviewed_by, review_notes, created_at, updated_at, created_by, updated_by, version) FROM stdin;
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
-- Data for Name: account_types; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.account_types (id, type_code, name, description, features, restrictions, is_active, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.accounts (id, account_number, account_name, account_type_id, currency_code, current_balance, available_balance, hold_balance, status, open_date, last_activity_date, close_date, metadata, created_at, updated_at, created_by, updated_by, version) FROM stdin;
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: core; Owner: postgres
--

COPY core.clients (id, client_number, client_type, status, title, first_name, middle_name, last_name, date_of_birth, gender, marital_status, email, email_verified, phone, phone_verified, occupation, employer_name, employment_status, annual_income, kyc_status, kyc_verified_at, kyc_verified_by, risk_level, relationship_manager_id, referral_source, created_at, updated_at, deleted_at, created_by, updated_by, version) FROM stdin;
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
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.permissions_id_seq', 26, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: postgres
--

SELECT pg_catalog.setval('auth.roles_id_seq', 17, true);


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
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


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
-- Name: kyc_verifications kyc_verifications_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.kyc_verifications
    ADD CONSTRAINT kyc_verifications_pkey PRIMARY KEY (id);


--
-- Name: sanctions_matches sanctions_matches_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT sanctions_matches_pkey PRIMARY KEY (id);


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
-- Name: account_balances uq_daily_balance; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_balances
    ADD CONSTRAINT uq_daily_balance UNIQUE (account_id, balance_date);


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
-- Name: idx_password_reset_tokens_token_hash; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_password_reset_tokens_token_hash ON auth.password_reset_tokens USING btree (token_hash);


--
-- Name: idx_password_reset_tokens_user_id; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_password_reset_tokens_user_id ON auth.password_reset_tokens USING btree (user_id);


--
-- Name: idx_sessions_expires; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_sessions_expires ON auth.sessions USING btree (expires_at);


--
-- Name: idx_sessions_expires_at; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_sessions_expires_at ON auth.sessions USING btree (expires_at);


--
-- Name: idx_sessions_token_hash; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_sessions_token_hash ON auth.sessions USING btree (token_hash);


--
-- Name: idx_sessions_user; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_sessions_user ON auth.sessions USING btree (user_id);


--
-- Name: idx_sessions_user_id; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_sessions_user_id ON auth.sessions USING btree (user_id);


--
-- Name: idx_users_created_at; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_created_at ON auth.users USING btree (created_at);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_email_lower ON auth.users USING btree (lower((email)::text));


--
-- Name: idx_users_last_login; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_last_login ON auth.users USING btree (last_login_at);


--
-- Name: idx_users_status; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_status ON auth.users USING btree (status);


--
-- Name: idx_audit_logs_composite; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX idx_audit_logs_composite ON compliance.audit_logs USING btree (event_type, event_time);


--
-- Name: idx_currencies_active; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_currencies_active ON config.currencies USING btree (is_active);


--
-- Name: idx_exchange_rates_date; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_exchange_rates_date ON config.exchange_rates USING btree (effective_date);


--
-- Name: idx_exchange_rates_from; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_exchange_rates_from ON config.exchange_rates USING btree (from_currency);


--
-- Name: idx_exchange_rates_to; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_exchange_rates_to ON config.exchange_rates USING btree (to_currency);


--
-- Name: idx_fee_rules_active; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_fee_rules_active ON config.fee_structure_rules USING btree (is_active);


--
-- Name: idx_fee_rules_structure; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_fee_rules_structure ON config.fee_structure_rules USING btree (fee_structure_id);


--
-- Name: idx_fee_structures_active; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_fee_structures_active ON config.fee_structures USING btree (is_active);


--
-- Name: idx_fee_structures_type; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_fee_structures_type ON config.fee_structures USING btree (fee_type);


--
-- Name: idx_settings_category; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_settings_category ON config.settings USING btree (category);


--
-- Name: idx_settings_key; Type: INDEX; Schema: config; Owner: postgres
--

CREATE INDEX idx_settings_key ON config.settings USING btree (setting_key);


--
-- Name: idx_account_balances_account; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_account ON core.account_balances USING btree (account_id);


--
-- Name: idx_account_balances_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_balances_date ON core.account_balances USING btree (balance_date);


--
-- Name: idx_account_holders_account; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_account ON core.account_holders USING btree (account_id);


--
-- Name: idx_account_holders_client; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_client ON core.account_holders USING btree (client_id);


--
-- Name: idx_account_holders_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_account_holders_type ON core.account_holders USING btree (holder_type);


--
-- Name: idx_accounts_balance; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_balance ON core.accounts USING btree (current_balance);


--
-- Name: idx_accounts_currency; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_currency ON core.accounts USING btree (currency_code);


--
-- Name: idx_accounts_number; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_number ON core.accounts USING btree (account_number);


--
-- Name: idx_accounts_open_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_open_date ON core.accounts USING btree (open_date);


--
-- Name: idx_accounts_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_status ON core.accounts USING btree (status);


--
-- Name: idx_accounts_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_accounts_type ON core.accounts USING btree (account_type_id);


--
-- Name: idx_clients_client_number; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_client_number ON core.clients USING btree (client_number);


--
-- Name: idx_clients_created_at; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_created_at ON core.clients USING btree (created_at);


--
-- Name: idx_clients_kyc_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_kyc_status ON core.clients USING btree (kyc_status);


--
-- Name: idx_clients_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_clients_status ON core.clients USING btree (status);


--
-- Name: idx_transactions_created_by; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_created_by ON core.transactions USING btree (created_by);


--
-- Name: idx_transactions_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_date ON core.transactions USING btree (transaction_date);


--
-- Name: idx_transactions_reference; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_reference ON core.transactions USING btree (transaction_reference);


--
-- Name: idx_transactions_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_status ON core.transactions USING btree (status);


--
-- Name: idx_transactions_type; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_type ON core.transactions USING btree (transaction_type_id);


--
-- Name: idx_transactions_type_status; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_transactions_type_status ON core.transactions USING btree (transaction_type_id, status);


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
-- Name: sanctions_matches fk_sanctions_client; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT fk_sanctions_client FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE SET NULL;


--
-- Name: sanctions_matches fk_sanctions_transaction; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sanctions_matches
    ADD CONSTRAINT fk_sanctions_transaction FOREIGN KEY (transaction_id) REFERENCES core.transactions(id) ON DELETE SET NULL;


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
-- Name: account_balances account_balances_account_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_balances
    ADD CONSTRAINT account_balances_account_id_fkey FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;


--
-- Name: account_holders account_holders_account_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_holders
    ADD CONSTRAINT account_holders_account_id_fkey FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;


--
-- Name: account_holders account_holders_client_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.account_holders
    ADD CONSTRAINT account_holders_client_id_fkey FOREIGN KEY (client_id) REFERENCES core.clients(id) ON DELETE CASCADE;


--
-- Name: accounts accounts_account_type_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT accounts_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES core.account_types(id);


--
-- Name: accounts accounts_currency_code_fkey; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.accounts
    ADD CONSTRAINT accounts_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES config.currencies(code);


--
-- Name: transactions fk_transactions_type; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.transactions
    ADD CONSTRAINT fk_transactions_type FOREIGN KEY (transaction_type_id) REFERENCES core.transaction_types(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

