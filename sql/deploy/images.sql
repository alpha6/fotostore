-- Deploy fotostore:images to sqlite

BEGIN;

CREATE TABLE images (
    file_id      INTEGER  PRIMARY KEY AUTOINCREMENT,
    owner_id     INTEGER  NOT NULL,
    file_name    TEXT     NOT NULL,
    created_time DATETIME NOT NULL
                          DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (
        owner_id
    )
    REFERENCES users (user_id) ON DELETE CASCADE
);

COMMIT;
