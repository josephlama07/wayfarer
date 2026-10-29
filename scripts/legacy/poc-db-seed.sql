BEGIN;

DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS waypoints;

CREATE TABLE waypoints (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  latitude numeric(9,6) NOT NULL,
  longitude numeric(9,6) NOT NULL
);

CREATE TABLE trips (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title text NOT NULL,
  destination text NOT NULL,
  status text NOT NULL CHECK (status IN ('planned', 'active', 'completed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO waypoints (name, latitude, longitude) VALUES
  ('Tokyo Station', 35.681236, 139.767125),
  ('Senso-ji Temple', 35.714765, 139.796655),
  ('Shibuya Crossing', 35.659500, 139.700500);

INSERT INTO trips (title, destination, status) VALUES
  ('Tokyo starter route', 'Tokyo, Japan', 'planned'),
  ('Kansai food trail', 'Osaka, Japan', 'active');

COMMIT;