CREATE USER users_user WITH PASSWORD 'users_dev_pw';
CREATE DATABASE users_db OWNER users_user;

CREATE USER events_user WITH PASSWORD 'events_dev_pw';
CREATE DATABASE events_db OWNER events_user;

CREATE USER bookings_user WITH PASSWORD 'bookings_dev_pw';
CREATE DATABASE bookings_db OWNER bookings_user;

CREATE USER payments_user WITH PASSWORD 'payments_dev_pw';
CREATE DATABASE payments_db OWNER payments_user;

CREATE USER notifications_user WITH PASSWORD 'notifications_dev_pw';
CREATE DATABASE notifications_db OWNER notifications_user;