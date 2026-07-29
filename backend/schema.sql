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

CREATE INDEX IF NOT EXISTS idx_offers_product ON offers (product_id);
CREATE INDEX IF NOT EXISTS idx_items_owner ON inventory_items (owner);
CREATE INDEX IF NOT EXISTS idx_orders_item ON orders (item_id);
