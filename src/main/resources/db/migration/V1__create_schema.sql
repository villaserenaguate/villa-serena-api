CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_types (
  id              BIGSERIAL     PRIMARY KEY,
  name            VARCHAR(100)  NOT NULL,
  description     TEXT,
  image_url       TEXT,
  price_per_night NUMERIC(10,2) NOT NULL CHECK (price_per_night >= 0),
  max_adults      SMALLINT      NOT NULL CHECK (max_adults > 0),
  max_children    SMALLINT      NOT NULL DEFAULT 0 CHECK (max_children >= 0)
);

CREATE TABLE rooms (
  id           BIGSERIAL   PRIMARY KEY,
  room_type_id BIGINT      NOT NULL REFERENCES room_types(id),
  room_number  VARCHAR(10) NOT NULL UNIQUE,
  active       BOOLEAN     NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_rooms_room_type ON rooms (room_type_id);

CREATE TABLE bookings (
  id              BIGSERIAL     PRIMARY KEY,
  code            VARCHAR(12)   NOT NULL UNIQUE,
  room_id         BIGINT        NOT NULL REFERENCES rooms(id),
  guest_name      VARCHAR(150)  NOT NULL,
  guest_email     VARCHAR(150)  NOT NULL,
  guest_phone     VARCHAR(30),
  check_in        DATE          NOT NULL,
  check_out       DATE          NOT NULL,
  adults          SMALLINT      NOT NULL CHECK (adults > 0),
  children        SMALLINT      NOT NULL DEFAULT 0 CHECK (children >= 0),
  price_per_night NUMERIC(10,2) NOT NULL,
  total_price     NUMERIC(10,2) NOT NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'CONFIRMED'
                  CHECK (status IN ('CONFIRMED', 'CANCELLED')),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (check_out > check_in),
  EXCLUDE USING gist (
    room_id WITH =,
    daterange(check_in, check_out) WITH &&
  ) WHERE (status = 'CONFIRMED')
);
CREATE INDEX idx_bookings_room_dates ON bookings (room_id, check_in, check_out);
