-- Deploy fotostore:images to sqlite

BEGIN;

PRAGMA foreign_keys = 0;

CREATE TABLE images_rever_temp_table AS SELECT *
                                          FROM images;

DROP TABLE images;

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

INSERT INTO images (
                       file_id,
                       owner_id,
                       file_name,
                       created_time
                   )
                   SELECT file_id,
                          owner_id,
                          file_name,
                          created_time
                     FROM images_rever_temp_table;

DROP TABLE images_rever_temp_table;

PRAGMA foreign_keys = 1;

COMMIT;
