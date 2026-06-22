TRUNCATE TABLE contacts RESTART IDENTITY CASCADE;

INSERT INTO contacts (first_name, last_name)
VALUES ('Alice',    'Martin'),
       ('Bob',      'Johnson'),
       ('Charlie',  'Dupont'),
       ('Diana',    'Smith'),
       ('Élodie',   'Petit'),
       ('Frank',    'Williams'),
       ('Ghita',    'Benali'),
       ('Hugo',     'Lefebvre'),
       ('Irina',    'Kuznetsova'),
       ('James',    'Brown');
