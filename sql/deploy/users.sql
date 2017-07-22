-- Deploy fotostore:users to sqlite

BEGIN;

CREATE TABLE users (
    nickname  TEXT,
    password  TEXT     NOT NULL,
    fullname  TEXT     NOT NULL,
    timestamp DATETIME NOT NULL
                       DEFAULT CURRENT_TIMESTAMP,
    user_id   INTEGER  PRIMARY KEY AUTOINCREMENT
);

COMMIT;
