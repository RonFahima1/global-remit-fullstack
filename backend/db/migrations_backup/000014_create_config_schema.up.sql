-- +goose Up
CREATE SCHEMA IF NOT EXISTS config;

CREATE TABLE IF NOT EXISTS config.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT,
    data_type VARCHAR(20) NOT NULL,
    description TEXT,
    is_encrypted BOOLEAN NOT NULL DEFAULT false,
    is_sensitive BOOLEAN NOT NULL DEFAULT false,
    min_value TEXT,
    max_value TEXT,
    allowed_values JSONB,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_setting_key UNIQUE (setting_key),
    CONSTRAINT chk_data_type CHECK (
        data_type IN ('string', 'number', 'boolean', 'json', 'date', 'datetime')
    )
);

CREATE INDEX IF NOT EXISTS idx_settings_category ON config.settings(category);
CREATE INDEX IF NOT EXISTS idx_settings_key ON config.settings(setting_key);

CREATE TABLE IF NOT EXISTS config.currencies (
    code CHAR(3) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    decimal_places INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_base_currency BOOLEAN NOT NULL DEFAULT false,
    is_fiat BOOLEAN NOT NULL DEFAULT true,
    is_crypto BOOLEAN GENERATED ALWAYS AS (NOT is_fiat) STORED,
    format_pattern VARCHAR(50) NOT NULL DEFAULT '#,##0.00',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT chk_decimal_places CHECK (decimal_places BETWEEN 0 AND 8)
);

CREATE INDEX IF NOT EXISTS idx_currencies_active ON config.currencies(is_active);

CREATE TABLE IF NOT EXISTS config.exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,
    rate NUMERIC(24, 12) NOT NULL,
    effective_date DATE NOT NULL,
    expiry_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    source VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_from_currency FOREIGN KEY (from_currency) 
        REFERENCES config.currencies(code) ON DELETE CASCADE,
    CONSTRAINT fk_to_currency FOREIGN KEY (to_currency) 
        REFERENCES config.currencies(code) ON DELETE CASCADE,
    CONSTRAINT uq_currency_pair_date UNIQUE (from_currency, to_currency, effective_date)
);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_from ON config.exchange_rates(from_currency);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_to ON config.exchange_rates(to_currency);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_date ON config.exchange_rates(effective_date);

CREATE TABLE IF NOT EXISTS config.fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    fee_type VARCHAR(50) NOT NULL,
    calculation_method VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    applies_to_all_transaction_types BOOLEAN NOT NULL DEFAULT false,
    applies_to_all_account_types BOOLEAN NOT NULL DEFAULT false,
    applies_to_all_currencies BOOLEAN NOT NULL DEFAULT false,
    min_fee_amount NUMERIC(20, 4),
    max_fee_amount NUMERIC(20, 4),
    fee_percentage NUMERIC(5, 2),
    fixed_fee_amount NUMERIC(20, 4),
    fee_currency CHAR(3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_fee_currency FOREIGN KEY (fee_currency) 
        REFERENCES config.currencies(code) ON DELETE SET NULL,
    CONSTRAINT chk_fee_type CHECK (
        fee_type IN ('transaction', 'account', 'service', 'penalty', 'other')
    ),
    CONSTRAINT chk_calculation_method CHECK (
        calculation_method IN ('fixed', 'percentage', 'tiered', 'volume_based')
    )
);

CREATE INDEX IF NOT EXISTS idx_fee_structures_active ON config.fee_structures(is_active);
CREATE INDEX IF NOT EXISTS idx_fee_structures_type ON config.fee_structures(fee_type);

CREATE TABLE IF NOT EXISTS config.fee_structure_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    rule_condition JSONB NOT NULL,
    fee_value NUMERIC(20, 4) NOT NULL,
    fee_percentage NUMERIC(5, 2),
    min_amount NUMERIC(20, 4),
    max_amount NUMERIC(20, 4),
    currency CHAR(3),
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_fee_structure FOREIGN KEY (fee_structure_id) 
        REFERENCES config.fee_structures(id) ON DELETE CASCADE,
    CONSTRAINT fk_currency FOREIGN KEY (currency) 
        REFERENCES config.currencies(code) ON DELETE SET NULL,
    CONSTRAINT chk_rule_type CHECK (
        rule_type IN ('amount_range', 'transaction_type', 'account_type', 'customer_tier', 'channel')
    )
);

CREATE INDEX IF NOT EXISTS idx_fee_rules_structure ON config.fee_structure_rules(fee_structure_id);
CREATE INDEX IF NOT EXISTS idx_fee_rules_active ON config.fee_structure_rules(is_active);

-- +goose Down
DROP TABLE IF EXISTS config.fee_structure_rules;
DROP TABLE IF EXISTS config.fee_structures;
DROP TABLE IF EXISTS config.exchange_rates;
DROP TABLE IF EXISTS config.currencies;
DROP TABLE IF EXISTS config.settings;
DROP SCHEMA IF EXISTS config;
