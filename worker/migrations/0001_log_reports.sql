-- Logs someone sent from the app's Help → Send Logs.
CREATE TABLE log_reports (
  id          TEXT PRIMARY KEY,
  received_at TEXT NOT NULL,
  username    TEXT NOT NULL,
  full_name   TEXT NOT NULL,
  computer    TEXT NOT NULL,
  platform    TEXT NOT NULL,
  os_version  TEXT NOT NULL,
  model       TEXT NOT NULL,
  app_version TEXT NOT NULL,
  app_commit  TEXT NOT NULL,
  channel     TEXT NOT NULL,
  note        TEXT NOT NULL,
  report      TEXT NOT NULL,
  ip          TEXT NOT NULL,
  country     TEXT NOT NULL
);

CREATE INDEX log_reports_received_at ON log_reports (received_at);
