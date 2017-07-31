-- Deploy fotostore:user_images to sqlite

BEGIN;

CREATE TABLE user_images (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER REFERENCES users (user_id) ON DELETE CASCADE,
    image_id  INTEGER REFERENCES images (file_id) ON DELETE CASCADE
);


COMMIT;
