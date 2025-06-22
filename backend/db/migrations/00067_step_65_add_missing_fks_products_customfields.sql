-- +goose Up
-- Add missing foreign key constraints for product and custom field/EAV tables

-- core.account_products
-- +goose StatementBegin
ALTER TABLE core.account_products ADD CONSTRAINT fk_account_products_account FOREIGN KEY (account_id) REFERENCES core.accounts(id) ON DELETE CASCADE;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.account_products ADD CONSTRAINT fk_account_products_product FOREIGN KEY (product_id) REFERENCES core.products(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- core.product_features
-- +goose StatementBegin
ALTER TABLE core.product_features ADD CONSTRAINT fk_product_features_product FOREIGN KEY (product_id) REFERENCES core.products(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- core.custom_field_values
-- +goose StatementBegin
ALTER TABLE core.custom_field_values ADD CONSTRAINT fk_custom_field_values_field FOREIGN KEY (field_id) REFERENCES core.custom_fields(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- +goose Down
-- Remove the added foreign key constraints
-- +goose StatementBegin
ALTER TABLE core.account_products DROP CONSTRAINT IF EXISTS fk_account_products_account;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.account_products DROP CONSTRAINT IF EXISTS fk_account_products_product;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.product_features DROP CONSTRAINT IF EXISTS fk_product_features_product;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE core.custom_field_values DROP CONSTRAINT IF EXISTS fk_custom_field_values_field;
-- +goose StatementEnd 