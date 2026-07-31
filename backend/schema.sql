-- Idempotent: safe to run on every boot. ponytail: one file instead of a
-- migration tool, which earns its keep only once schemas start changing
-- under live data.

CREATE TABLE IF NOT EXISTS products (
    id          TEXT PRIMARY KEY,
    name        TEXT           NOT NULL,
    category    TEXT           NOT NULL,
    tab         TEXT           NOT NULL DEFAULT 'All',
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    image_url   TEXT           NOT NULL,
    store       TEXT           NOT NULL,
    description TEXT           NOT NULL DEFAULT ''
);

-- A product sold by another vendor at their own price.
CREATE TABLE IF NOT EXISTS offers (
    product_id TEXT           NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    store      TEXT           NOT NULL,
    price      NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (product_id, store)
);

CREATE TABLE IF NOT EXISTS shops (
    name      TEXT PRIMARY KEY,
    tagline   TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    tab       TEXT NOT NULL DEFAULT 'All'
);

-- One store per seller, keyed by the email they signed in with.
CREATE TABLE IF NOT EXISTS seller_stores (
    owner      TEXT PRIMARY KEY,
    name       TEXT   NOT NULL,
    location   TEXT   NOT NULL,
    city       TEXT   NOT NULL,
    categories TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS inventory_items (
    id          TEXT PRIMARY KEY,
    owner       TEXT           NOT NULL REFERENCES seller_stores (owner) ON DELETE CASCADE,
    title       TEXT           NOT NULL,
    description TEXT           NOT NULL DEFAULT '',
    category    TEXT           NOT NULL DEFAULT '',
    price       NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    -- The floor lives in the schema too, so no code path can drive stock
    -- negative even by accident.
    stock       INTEGER        NOT NULL DEFAULT 0 CHECK (stock >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
    id         TEXT PRIMARY KEY,
    item_id    TEXT           NOT NULL REFERENCES inventory_items (id) ON DELETE CASCADE,
    item_title TEXT           NOT NULL,
    units      INTEGER        NOT NULL CHECK (units > 0),
    amount     NUMERIC(10, 2) NOT NULL,
    stage      TEXT           NOT NULL CHECK (stage IN ('received', 'accepted', 'delivered')),
    placed_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- One live sign-in code per address; a resend replaces the row.
CREATE TABLE IF NOT EXISTS login_codes (
    email      TEXT PRIMARY KEY,
    code_hash  TEXT        NOT NULL, -- sha256, so the table never holds a usable code
    expires_at TIMESTAMPTZ NOT NULL,
    sent_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    attempts   INTEGER     NOT NULL DEFAULT 0
);

-- Sessions hold hashes, never the tokens themselves: a leaked database dump
-- cannot be used to sign in. The access token is short-lived and the refresh
-- token is rotated on every use, so a stolen one is good for one call at most.
DROP TABLE IF EXISTS sessions; -- superseded by the shape below
CREATE TABLE IF NOT EXISTS auth_sessions (
    access_hash        TEXT PRIMARY KEY,
    refresh_hash       TEXT        NOT NULL UNIQUE,
    email              TEXT        NOT NULL,
    expires_at         TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sessions_email ON auth_sessions (email);

-- One row per browser that agreed to notifications. The endpoint stores the
-- Firebase Messaging token with an internal fcm: prefix.
CREATE TABLE IF NOT EXISTS push_subscriptions (
    endpoint   TEXT PRIMARY KEY,
    email      TEXT        NOT NULL,
    p256dh     TEXT        NOT NULL DEFAULT '',
    auth       TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_push_email ON push_subscriptions (email);
ALTER TABLE push_subscriptions
    ALTER COLUMN p256dh SET DEFAULT '',
    ALTER COLUMN auth SET DEFAULT '';

-- Photos live in Cloudinary; Postgres keeps the URLs. Added with ALTER so an
-- existing database picks them up on the next boot.
ALTER TABLE seller_stores
    ADD COLUMN IF NOT EXISTS photo_url TEXT NOT NULL DEFAULT '';
ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS image_urls TEXT[] NOT NULL DEFAULT '{}';

-- Postgres hands out ids, not the clock: two requests in the same microsecond
-- used to generate the same primary key and one of them lost.
CREATE SEQUENCE IF NOT EXISTS inventory_item_ids;
CREATE SEQUENCE IF NOT EXISTS order_ids;
ALTER TABLE inventory_items
    ALTER COLUMN id SET DEFAULT 'item-' || nextval('inventory_item_ids');
ALTER TABLE orders
    ALTER COLUMN id SET DEFAULT 'order-' || nextval('order_ids');

CREATE INDEX IF NOT EXISTS idx_offers_product ON offers (product_id);
CREATE INDEX IF NOT EXISTS idx_items_owner ON inventory_items (owner);
CREATE INDEX IF NOT EXISTS idx_orders_item ON orders (item_id);
-- ponytail: plain indexes for the tab/category filters. The ?q= search still
-- scans; add pg_trgm when the catalog outgrows a few thousand rows.
CREATE INDEX IF NOT EXISTS idx_products_tab ON products (tab);
CREATE INDEX IF NOT EXISTS idx_products_category ON products (category);
-- Placing an order sums this seller's outstanding units for one item.
CREATE INDEX IF NOT EXISTS idx_orders_item_stage ON orders (item_id, stage);
