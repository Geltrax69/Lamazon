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

-- Everyone who has ever signed in. The row is created on first verified code
-- and never disappears, so a returning person is recognised rather than
-- re-registered.
--
-- The public id is what a person sees and quotes at support; the email stays
-- the key everything else joins on.
CREATE SEQUENCE IF NOT EXISTS user_ids START 1001;
CREATE TABLE IF NOT EXISTS users (
    email      TEXT PRIMARY KEY,
    public_id  TEXT        NOT NULL UNIQUE DEFAULT 'LMZ-' || nextval('user_ids'),
    name       TEXT        NOT NULL DEFAULT '',
    phone      TEXT        NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The address book, one row per saved address. Kept per person rather than
-- per device so it follows them to a new browser.
CREATE TABLE IF NOT EXISTS addresses (
    id         TEXT PRIMARY KEY,
    email      TEXT        NOT NULL REFERENCES users (email) ON DELETE CASCADE,
    label      TEXT        NOT NULL DEFAULT 'Home',
    line       TEXT        NOT NULL,
    city       TEXT        NOT NULL,
    pincode    TEXT        NOT NULL DEFAULT '',
    name       TEXT        NOT NULL DEFAULT '',  -- who receives it
    phone      TEXT        NOT NULL DEFAULT '',  -- and on what number
    is_default BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE SEQUENCE IF NOT EXISTS address_ids;
ALTER TABLE addresses ALTER COLUMN id SET DEFAULT 'addr-' || nextval('address_ids');
CREATE INDEX IF NOT EXISTS idx_addresses_email ON addresses (email);

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

-- A store is not a storefront until a person has looked at it. New stores
-- arrive pending and stay invisible to shoppers, and their owner cannot add
-- stock, until an admin approves them.
--
-- The two ALTERs are deliberate: adding the column with 'approved' backfills
-- every store that existed before review was a thing (they are already live,
-- and pending them would empty the catalogue), then the default flips so
-- everything opened from now on waits.
ALTER TABLE seller_stores
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE seller_stores
    ALTER COLUMN status SET DEFAULT 'pending';
ALTER TABLE seller_stores
    ADD COLUMN IF NOT EXISTS reject_reason TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE seller_stores DROP CONSTRAINT IF EXISTS seller_stores_status_check;
ALTER TABLE seller_stores ADD CONSTRAINT seller_stores_status_check
    CHECK (status IN ('pending', 'approved', 'rejected'));

-- Whoever runs Lamazon. Passwords are PBKDF2-SHA256 with a per-row salt, so
-- the table never holds anything usable. Seeded from ADMIN_USER /
-- ADMIN_PASSWORD at boot, never from source.
CREATE TABLE IF NOT EXISTS admins (
    username   TEXT PRIMARY KEY,
    pass_hash  TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A delivery rider, created by an admin who types in their number. The PIN is
-- generated here and shown to the admin once; the rider signs in with number
-- and PIN at /delivery.
CREATE TABLE IF NOT EXISTS riders (
    phone      TEXT PRIMARY KEY,
    name       TEXT        NOT NULL DEFAULT '',
    pin_hash   TEXT        NOT NULL,
    active     BOOLEAN     NOT NULL DEFAULT true,
    delivered  INTEGER     NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Staff sign-ins (admin and rider) share one table: same shape, same
-- expiry, and one place to look when a token has to be revoked.
CREATE TABLE IF NOT EXISTS staff_sessions (
    token_hash TEXT PRIMARY KEY,
    role       TEXT        NOT NULL CHECK (role IN ('admin', 'rider')),
    subject    TEXT        NOT NULL, -- admin username, or rider phone
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- An order carries who it is for, frozen at the moment it was placed: a later
-- edit to the address book must not redirect a bag already on its way.
-- store_owner is copied for the same reason, and is what every seller-side
-- query filters on, so one seller can never touch another's order.
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS buyer_email      TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS store_owner      TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS store_name       TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS receiver_name    TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS receiver_phone   TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS receiver_address TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS reject_reason    TEXT NOT NULL DEFAULT '',
    -- The four digits the buyer reads out at the door. Kept in the clear
    -- because the buyer has to be able to read it back in the app; it is only
    -- ever sent to them, never to the rider, which is what makes typing it
    -- proof that the two of them met.
    ADD COLUMN IF NOT EXISTS delivery_code    TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS rider_phone      TEXT NOT NULL DEFAULT '',
    -- Who the admin wants on this one. Separate from rider_phone, which is
    -- only set when a rider actually has the bag: an order can be spoken for
    -- before anyone has picked it up. Empty means anyone may take it.
    ADD COLUMN IF NOT EXISTS assigned_to      TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS accepted_at      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS picked_at        TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS delivered_at     TIMESTAMPTZ;

-- Rejected, picked: the stages the workflow gained. Dropped first so the
-- file stays runnable on every boot.
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_stage_check;
ALTER TABLE orders ADD CONSTRAINT orders_stage_check
    CHECK (stage IN ('received', 'accepted', 'rejected', 'picked', 'delivered'));

-- Orders placed before the column existed still belong to someone; the item
-- says who, and without this they would vanish from their seller's list.
UPDATE orders o SET store_owner = i.owner
FROM inventory_items i WHERE i.id = o.item_id AND o.store_owner = '';
UPDATE orders o SET store_name = s.name
FROM seller_stores s WHERE s.owner = o.store_owner AND o.store_name = '';

CREATE INDEX IF NOT EXISTS idx_orders_buyer ON orders (buyer_email);
CREATE INDEX IF NOT EXISTS idx_orders_store ON orders (store_owner);
CREATE INDEX IF NOT EXISTS idx_orders_rider ON orders (rider_phone);

CREATE INDEX IF NOT EXISTS idx_offers_product ON offers (product_id);
CREATE INDEX IF NOT EXISTS idx_items_owner ON inventory_items (owner);
CREATE INDEX IF NOT EXISTS idx_orders_item ON orders (item_id);
-- ponytail: plain indexes for the tab/category filters. The ?q= search still
-- scans; add pg_trgm when the catalog outgrows a few thousand rows.
CREATE INDEX IF NOT EXISTS idx_products_tab ON products (tab);
CREATE INDEX IF NOT EXISTS idx_products_category ON products (category);
-- Placing an order sums this seller's outstanding units for one item.
CREATE INDEX IF NOT EXISTS idx_orders_item_stage ON orders (item_id, stage);

-- What the item costs before the discount. Zero means the seller did not set
-- one, which is the honest default: every existing row predates the field, and
-- backfilling it from price would invent a 0% discount on all of them.
--
-- The check is what stops a "discount" that raises the price. Equal is allowed
-- so a seller can clear a sale by matching the two rather than by knowing to
-- type a zero.
ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS mrp NUMERIC(10, 2) NOT NULL DEFAULT 0;
ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_mrp_check;
ALTER TABLE inventory_items ADD CONSTRAINT inventory_items_mrp_check
    CHECK (mrp = 0 OR mrp >= price);

-- The departments across the top of the shop, and the categories under each.
-- One table: a department is a row with no parent, a category is a row whose
-- parent names one. Two tables would duplicate the name, the ordering and
-- every query that walks them.
--
-- The name is the key because that is what products already store — orders,
-- inventory and seller stores all reference a category by its text. Which is
-- also why there is no rename: it would orphan every row pointing at the old
-- one, and an admin cannot be expected to know that.
CREATE TABLE IF NOT EXISTS catalog_categories (
    name     TEXT PRIMARY KEY,
    parent   TEXT    NOT NULL DEFAULT '',
    icon     TEXT    NOT NULL DEFAULT '',
    colour   TEXT    NOT NULL DEFAULT '',
    position INTEGER NOT NULL DEFAULT 0
);

-- The five the app shipped with, so a fresh install has a shop rather than an
-- empty navigation bar. Only when the table is empty: this runs at every
-- boot, and re-adding a department the admin deleted would make deletion look
-- like it silently failed.
INSERT INTO catalog_categories (name, parent, icon, colour, position)
SELECT * FROM (VALUES
    ('Electronics', '', 'headphones', '#2F6FED', 1),
    ('Grocery',     '', 'carrot',     '#43A047', 2),
    ('Food',        '', 'utensils',   '#FF8A3D', 3),
    ('Gifts',       '', 'gift',       '#9C6ADE', 4),
    ('Beauty',      '', 'brush',      '#F06292', 5)
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM catalog_categories);

CREATE INDEX IF NOT EXISTS idx_categories_parent
    ON catalog_categories (parent, position);
