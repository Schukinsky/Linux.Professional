--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Drop databases (except postgres and template1)
--

DROP DATABASE gate;




--
-- Drop roles
--

DROP ROLE admin_user;
DROP ROLE postgres;


--
-- Roles
--

CREATE ROLE admin_user;
ALTER ROLE admin_user WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:NQal15G9npXwtsBHV5z63g==$g0GOZNV3t4exh76PXbraGAl7+mp/GaqQd/JcFWYFqX0=:t8JUkHUd+CBGNZDliH5+nRLNyj5ukcmFlhaAYTa6pxQ=';
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS;






--
-- Databases
--

--
-- Database "template1" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

UPDATE pg_catalog.pg_database SET datistemplate = false WHERE datname = 'template1';
DROP DATABASE template1;
--
-- Name: template1; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C.UTF-8';


ALTER DATABASE template1 OWNER TO postgres;

\connect template1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE template1; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE template1 IS 'default template for new databases';


--
-- Name: template1; Type: DATABASE PROPERTIES; Schema: -; Owner: postgres
--

ALTER DATABASE template1 IS_TEMPLATE = true;


\connect template1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE template1; Type: ACL; Schema: -; Owner: postgres
--

REVOKE CONNECT,TEMPORARY ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


--
-- PostgreSQL database dump complete
--

--
-- Database "gate" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: gate; Type: DATABASE; Schema: -; Owner: admin_user
--

CREATE DATABASE gate WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C.UTF-8';


ALTER DATABASE gate OWNER TO admin_user;

\connect gate

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: gate01; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA gate01;


ALTER SCHEMA gate01 OWNER TO postgres;

--
-- Name: generate_photo_name(); Type: FUNCTION; Schema: gate01; Owner: admin_user
--

CREATE FUNCTION gate01.generate_photo_name() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix TEXT := 'http://fileserver.org/images/img_';
    extension TEXT := '.jpg';
BEGIN
    RETURN CONCAT(prefix, TO_CHAR(current_timestamp, 'YYYYMMDDHH24MISS'), extension);
END;
$$;


ALTER FUNCTION gate01.generate_photo_name() OWNER TO admin_user;

--
-- Name: add_event_call(character varying, integer, character varying, character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.add_event_call(IN p_phone_number character varying, IN p_camera_id integer, IN p_vehicle_number character varying DEFAULT 'not detacted'::character varying, IN p_photo_url character varying DEFAULT gate01.generate_photo_name())
    LANGUAGE plpgsql
    AS $$
DECLARE
    pass_start_date DATE;
    pass_end_date DATE;
    pass_blocked BOOLEAN;
BEGIN
    -- Получаем информацию о пропуске
    SELECT start_date, end_date, blocked
    INTO pass_start_date, pass_end_date, pass_blocked
    FROM gate01.pass
    WHERE phone_number = p_phone_number;

    -- Если пропуска с указанным номером не существует, записываем событие с флагом неуспеха и выводим сообщение
    IF NOT FOUND THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE phone_number = p_phone_number), CURRENT_TIMESTAMP, p_vehicle_number, p_camera_id, p_photo_url, FALSE, 'Pass with number ' || p_phone_number || ' not found');
        RAISE NOTICE 'Event added but pass with number % not found', p_phone_number;
        RETURN;
    END IF;

    -- Если пропуск заблокирован, записываем событие с флагом неуспеха и выводим сообщение
    IF pass_blocked THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE phone_number = p_phone_number), CURRENT_TIMESTAMP, p_vehicle_number, p_camera_id, p_photo_url, FALSE, 'Pass with number ' || p_phone_number || ' is blocked');
        RAISE NOTICE 'Event added but pass with number % is blocked', p_phone_number;
        RETURN;
    END IF;

    -- Проверяем, что текущая дата находится в пределах даты начала - даты окончания пропуска
    IF CURRENT_DATE BETWEEN pass_start_date AND pass_end_date THEN
        -- Добавляем запись в таблицу event с успешным флагом и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success)
        VALUES ((SELECT id FROM gate01.pass WHERE phone_number = p_phone_number), CURRENT_TIMESTAMP, p_vehicle_number, p_camera_id, p_photo_url, TRUE);
        RAISE NOTICE 'Event added successfully for pass with number %', p_phone_number;
    ELSE
        -- Если текущая дата не находится в пределах даты начала - даты окончания пропуска, добавляем запись с флагом неуспеха и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE phone_number = p_phone_number), CURRENT_TIMESTAMP, p_vehicle_number, p_camera_id, p_photo_url, FALSE, 'Current date is not within the valid range for pass with number ' || p_phone_number);
        RAISE NOTICE 'Event added but current date is not within the valid range for pass with number %', p_phone_number;
    END IF;
END;
$$;


ALTER PROCEDURE gate01.add_event_call(IN p_phone_number character varying, IN p_camera_id integer, IN p_vehicle_number character varying, IN p_photo_url character varying) OWNER TO admin_user;

--
-- Name: add_event_camera_in(character varying, character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.add_event_camera_in(IN p_vehicle_number character varying, IN p_photo_url character varying DEFAULT gate01.generate_photo_name())
    LANGUAGE plpgsql
    AS $$
DECLARE
    pass_start_date DATE;
    pass_end_date DATE;
    pass_blocked BOOLEAN;
    camera_id INT := 1; --  значение 1 - въезд, 2 - выезд
BEGIN
    -- Получаем информацию о пропуске
    SELECT start_date, end_date, blocked
    INTO pass_start_date, pass_end_date, pass_blocked
    FROM gate01.pass
    WHERE vehicle_number = p_vehicle_number;

    -- Если пропуска с указанным номером не существует, записываем событие с флагом неуспеха и выводим сообщение
    IF NOT FOUND THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Pass with number ' || p_vehicle_number || ' not found');
        RAISE NOTICE 'Event added but pass with number % not found', p_vehicle_number;
        RETURN;
    END IF;

    -- Если пропуск заблокирован, записываем событие с флагом неуспеха и выводим сообщение
    IF pass_blocked THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Pass with number ' || p_vehicle_number || ' is blocked');
        RAISE NOTICE 'Event added but pass with number % is blocked', p_vehicle_number;
        RETURN;
    END IF;

    -- Проверяем, что текущая дата находится в пределах даты начала - даты окончания пропуска
    IF CURRENT_DATE BETWEEN pass_start_date AND pass_end_date THEN
        -- Добавляем запись в таблицу event с успешным флагом и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, TRUE);
        RAISE NOTICE 'Event added successfully for pass with number %', p_vehicle_number;
    ELSE
        -- Если текущая дата не находится в пределах даты начала - даты окончания пропуска, добавляем запись с флагом неуспеха и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Current date is not within the valid range for pass with number ' || p_vehicle_number);
        RAISE NOTICE 'Event added but current date is not within the valid range for pass with number %', p_vehicle_number;
    END IF;
END;
$$;


ALTER PROCEDURE gate01.add_event_camera_in(IN p_vehicle_number character varying, IN p_photo_url character varying) OWNER TO admin_user;

--
-- Name: add_event_camera_out(character varying, character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.add_event_camera_out(IN p_vehicle_number character varying, IN p_photo_url character varying DEFAULT gate01.generate_photo_name())
    LANGUAGE plpgsql
    AS $$
DECLARE
    pass_start_date DATE;
    pass_end_date DATE;
    pass_blocked BOOLEAN;
    camera_id INT := 2; --  значение 1 - въезд, 2 - выезд
BEGIN
    -- Получаем информацию о пропуске
    SELECT start_date, end_date, blocked
    INTO pass_start_date, pass_end_date, pass_blocked
    FROM gate01.pass
    WHERE vehicle_number = p_vehicle_number;

    -- Если пропуска с указанным номером не существует, записываем событие с флагом неуспеха и выводим сообщение
    IF NOT FOUND THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Pass with number ' || p_vehicle_number || ' not found');
        RAISE NOTICE 'Event added but pass with number % not found', p_vehicle_number;
        RETURN;
    END IF;

    -- Если пропуск заблокирован, записываем событие с флагом неуспеха и выводим сообщение
    IF pass_blocked THEN
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Pass with number ' || p_vehicle_number || ' is blocked');
        RAISE NOTICE 'Event added but pass with number % is blocked', p_vehicle_number;
        RETURN;
    END IF;

    -- Проверяем, что текущая дата находится в пределах даты начала - даты окончания пропуска
    IF CURRENT_DATE BETWEEN pass_start_date AND pass_end_date THEN
        -- Добавляем запись в таблицу event с успешным флагом и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, TRUE);
        RAISE NOTICE 'Event added successfully for pass with number %', p_vehicle_number;
    ELSE
        -- Если текущая дата не находится в пределах даты начала - даты окончания пропуска, добавляем запись с флагом неуспеха и выводим сообщение
        INSERT INTO gate01.event (FK_pass, event_time, vehicle_number, FK_camera, photo_url, success, note)
        VALUES ((SELECT id FROM gate01.pass WHERE vehicle_number = p_vehicle_number), CURRENT_TIMESTAMP, p_vehicle_number, camera_id, p_photo_url, FALSE, 'Current date is not within the valid range for pass with number ' || p_vehicle_number);
        RAISE NOTICE 'Event added but current date is not within the valid range for pass with number %', p_vehicle_number;
    END IF;
END;
$$;


ALTER PROCEDURE gate01.add_event_camera_out(IN p_vehicle_number character varying, IN p_photo_url character varying) OWNER TO admin_user;

--
-- Name: add_pass_phone(character varying, character varying, date, date); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.add_pass_phone(IN p_user_phone character varying, IN p_phone_number character varying, IN p_start_date date, IN p_end_date date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    -- Проверка, что дата начала меньше или равна дате окончания
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Start date % is greater than end date %', p_start_date, p_end_date;
        RETURN;
    END IF;

    -- Получаем ID пользователя по номеру телефона
    SELECT id INTO user_id FROM gate01.user WHERE phone = p_user_phone;

    -- Если пользователь с указанным номером телефона не найден, выбрасываем исключение
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User with phone % not found', p_user_phone;
        RETURN;
    END IF;

    -- Проверяем, существует ли уже пропуск с таким номером телефона
    IF EXISTS (SELECT 1 FROM gate01.pass WHERE phone_number = p_phone_number) THEN
        RAISE EXCEPTION 'Pass with phone number % already exists', p_phone_number;
        RETURN;
    END IF;

    -- Добавляем пропуск в таблицу pass
    INSERT INTO gate01.pass (FK_user, phone_number, start_date, end_date)
    VALUES (user_id, p_phone_number, p_start_date, p_end_date);

    -- Возвращаем сообщение о успешном добавлении пропуска
    RAISE NOTICE 'Pass added successfully for user with phone %', p_user_phone;
END;
$$;


ALTER PROCEDURE gate01.add_pass_phone(IN p_user_phone character varying, IN p_phone_number character varying, IN p_start_date date, IN p_end_date date) OWNER TO admin_user;

--
-- Name: add_pass_vehicle(character varying, character varying, date, date); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.add_pass_vehicle(IN p_user_phone character varying, IN p_vehicle_number character varying, IN p_start_date date, IN p_end_date date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    -- Проверка, что дата начала меньше или равна дате окончания
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Start date % is greater than end date %', p_start_date, p_end_date;
        RETURN;
    END IF;

    -- Получаем ID пользователя по номеру телефона
    SELECT id INTO user_id FROM gate01.user WHERE phone = p_user_phone;

    -- Если пользователь с указанным номером телефона не найден, выбрасываем исключение
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User with phone % not found', p_user_phone;
        RETURN;
    END IF;

    -- Проверяем, существует ли уже пропуск с таким номером транспортного средства
    IF EXISTS (SELECT 1 FROM gate01.pass WHERE vehicle_number = p_vehicle_number) THEN
        RAISE EXCEPTION 'Pass with vehicle number % already exists', p_vehicle_number;
        RETURN;
    END IF;

    -- Добавляем пропуск в таблицу pass
    INSERT INTO gate01.pass (FK_user, vehicle_number, start_date, end_date)
    VALUES (user_id, p_vehicle_number, p_start_date, p_end_date);

    -- Возвращаем сообщение о успешном добавлении пропуска
    RAISE NOTICE 'Pass added successfully for user with phone %', p_user_phone;
END;
$$;


ALTER PROCEDURE gate01.add_pass_vehicle(IN p_user_phone character varying, IN p_vehicle_number character varying, IN p_start_date date, IN p_end_date date) OWNER TO admin_user;

--
-- Name: block_allpass(character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.block_allpass(IN p_user_phone character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    -- Получаем ID пользователя по номеру телефона
    SELECT id INTO user_id FROM gate01.user WHERE phone = p_user_phone;

    -- Если пользователь с указанным номером телефона не найден, выбрасываем исключение
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User with phone % not found', p_user_phone;
        RETURN;
    END IF;

    -- Устанавливаем флаг блокировки TRUE для всех пропусков пользователя
    BEGIN
    UPDATE gate01.pass
    SET 
        blocked = TRUE
    WHERE
        FK_user = user_id;
	END;

    -- Возвращаем сообщение об успешной блокировки всех пропусков пользователя
    RAISE NOTICE 'All passes successfully blocked for user with phone %', p_user_phone;
END;
$$;


ALTER PROCEDURE gate01.block_allpass(IN p_user_phone character varying) OWNER TO admin_user;

--
-- Name: create_user(character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.create_user(IN p_last_name character varying, IN p_first_name character varying, IN p_middle_name character varying, IN p_phone character varying, IN p_email character varying, IN p_address character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    -- Проверяем, существует ли уже пользователь с таким номером телефона
    IF EXISTS (SELECT 1 FROM gate01.user WHERE phone = p_phone) THEN
        RAISE EXCEPTION 'User with phone % already exists', p_phone;
        RETURN;
    END IF;

    -- Добавляем новую запись в таблицу user
    INSERT INTO gate01.user (last_name, first_name, middle_name, phone, email, address)
    VALUES (p_last_name, p_first_name, p_middle_name, p_phone, p_email, p_address)
    RETURNING id INTO user_id;

    -- Возвращаем сообщение с id успешно созданного пользователя
    RAISE NOTICE 'User created successfully with id: %', user_id;
END;
$$;


ALTER PROCEDURE gate01.create_user(IN p_last_name character varying, IN p_first_name character varying, IN p_middle_name character varying, IN p_phone character varying, IN p_email character varying, IN p_address character varying) OWNER TO admin_user;

--
-- Name: edit_pass_phone(character varying, date, date, boolean); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.edit_pass_phone(IN in_phone_number character varying, IN in_start_date date, IN in_end_date date, IN in_blocked boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка, что дата начала меньше или равна дате окончания
    IF in_start_date > in_end_date THEN
        RAISE EXCEPTION 'Start date % is greater than end date %', in_start_date, in_end_date;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM gate01.pass WHERE phone_number = in_phone_number) THEN
        UPDATE gate01.pass
        SET 
            start_date = in_start_date,
            end_date = in_end_date,
            blocked = in_blocked
        WHERE
            phone_number = in_phone_number;
        
        -- Вывод сообщения при успешном изменении
        RAISE NOTICE 'Pass for phone number % successfully updated', in_phone_number;
    ELSE
        RAISE EXCEPTION 'Pass with phone number % does not exist', in_phone_number;
    END IF;
END;
$$;


ALTER PROCEDURE gate01.edit_pass_phone(IN in_phone_number character varying, IN in_start_date date, IN in_end_date date, IN in_blocked boolean) OWNER TO admin_user;

--
-- Name: edit_pass_vehicle(character varying, date, date, boolean); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.edit_pass_vehicle(IN in_vehicle_number character varying, IN in_start_date date, IN in_end_date date, IN in_blocked boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка, что дата начала меньше или равна дате окончания
    IF in_start_date > in_end_date THEN
        RAISE EXCEPTION 'Start date % is greater than end date %', in_start_date, in_end_date;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM gate01.pass WHERE vehicle_number = in_vehicle_number) THEN
        UPDATE gate01.pass
        SET 
            start_date = in_start_date,
            end_date = in_end_date,
            blocked = in_blocked
        WHERE
            vehicle_number = in_vehicle_number;
        
        -- Вывод сообщения при успешном изменении
        RAISE NOTICE 'Pass for vehicle number % successfully updated', in_vehicle_number;
    ELSE
        RAISE EXCEPTION 'Pass with vehicle number % does not exist', in_vehicle_number;
    END IF;
END;
$$;


ALTER PROCEDURE gate01.edit_pass_vehicle(IN in_vehicle_number character varying, IN in_start_date date, IN in_end_date date, IN in_blocked boolean) OWNER TO admin_user;

--
-- Name: get_passes_info(boolean, character varying); Type: FUNCTION; Schema: gate01; Owner: admin_user
--

CREATE FUNCTION gate01.get_passes_info(apply_conditions boolean DEFAULT false, u_phone character varying DEFAULT NULL::character varying) RETURNS TABLE(full_name text, user_address character varying, user_phone character varying, user_email character varying, pass text, start_date date, end_date date, blocked boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF apply_conditions THEN
        RETURN QUERY
        SELECT 
            CONCAT(u.last_name, ' ', u.first_name, ' ', COALESCE(u.middle_name, '')) AS full_name,
            u.address AS user_address,
            u.phone AS user_phone,
            u.email AS user_email,
            CONCAT(COALESCE(p.phone_number, ''), COALESCE(p.vehicle_number, '')) AS pass,
            p.start_date,
            p.end_date,
            p.blocked
        FROM 
            gate01.pass p
        LEFT JOIN 
            gate01.user u 
        ON 
            p.FK_user = u.id
        WHERE 
            p.blocked = FALSE
            AND CURRENT_DATE BETWEEN p.start_date AND p.end_date
            AND (u_phone IS NULL OR u.phone = u_phone)
        ORDER BY 
            u.address;
    ELSE
        RETURN QUERY
        SELECT 
            CONCAT(u.last_name, ' ', u.first_name, ' ', COALESCE(u.middle_name, '')) AS full_name,
            u.address AS user_address,
            u.phone AS user_phone,
            u.email AS user_email,
            CONCAT(COALESCE(p.phone_number, ''), COALESCE(p.vehicle_number, '')) AS pass,
            p.start_date,
            p.end_date,
            p.blocked
        FROM 
            gate01.pass p
        LEFT JOIN 
            gate01.user u 
        ON 
            p.FK_user = u.id
        WHERE
            u_phone IS NULL OR u.phone = u_phone
        ORDER BY 
            u.address;
    END IF;
END;
$$;


ALTER FUNCTION gate01.get_passes_info(apply_conditions boolean, u_phone character varying) OWNER TO admin_user;

--
-- Name: unblock_allpass(character varying); Type: PROCEDURE; Schema: gate01; Owner: admin_user
--

CREATE PROCEDURE gate01.unblock_allpass(IN p_user_phone character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_id INT;
BEGIN
    -- Получаем ID пользователя по номеру телефона
    SELECT id INTO user_id FROM gate01.user WHERE phone = p_user_phone;

    -- Если пользователь с указанным номером телефона не найден, выбрасываем исключение
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'User with phone % not found', p_user_phone;
        RETURN;
    END IF;

    -- Устанавливаем флаг блокировки FALSE для всех пропусков пользователя
    BEGIN
    UPDATE gate01.pass
    SET 
        blocked = FALSE
    WHERE
        FK_user = user_id;
	END;

    -- Возвращаем сообщение об успешной разблокировки всех пропусков пользователя
    RAISE NOTICE 'All passes successfully unblocked for user with phone %', p_user_phone;
END;
$$;


ALTER PROCEDURE gate01.unblock_allpass(IN p_user_phone character varying) OWNER TO admin_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: camera; Type: TABLE; Schema: gate01; Owner: admin_user
--

CREATE TABLE gate01.camera (
    id integer NOT NULL,
    name character varying(10) NOT NULL
);


ALTER TABLE gate01.camera OWNER TO admin_user;

--
-- Name: camera_id_seq; Type: SEQUENCE; Schema: gate01; Owner: admin_user
--

CREATE SEQUENCE gate01.camera_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gate01.camera_id_seq OWNER TO admin_user;

--
-- Name: camera_id_seq; Type: SEQUENCE OWNED BY; Schema: gate01; Owner: admin_user
--

ALTER SEQUENCE gate01.camera_id_seq OWNED BY gate01.camera.id;


--
-- Name: event; Type: TABLE; Schema: gate01; Owner: admin_user
--

CREATE TABLE gate01.event (
    id integer NOT NULL,
    fk_pass integer,
    event_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    vehicle_number character varying(20) NOT NULL,
    fk_camera integer,
    photo_url character varying(255) NOT NULL,
    success boolean NOT NULL,
    note character varying(255)
);


ALTER TABLE gate01.event OWNER TO admin_user;

--
-- Name: event_id_seq; Type: SEQUENCE; Schema: gate01; Owner: admin_user
--

CREATE SEQUENCE gate01.event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gate01.event_id_seq OWNER TO admin_user;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: gate01; Owner: admin_user
--

ALTER SEQUENCE gate01.event_id_seq OWNED BY gate01.event.id;


--
-- Name: pass; Type: TABLE; Schema: gate01; Owner: admin_user
--

CREATE TABLE gate01.pass (
    id integer NOT NULL,
    fk_user integer,
    phone_number character varying(20),
    vehicle_number character varying(20),
    start_date date NOT NULL,
    end_date date NOT NULL,
    blocked boolean DEFAULT false NOT NULL
);


ALTER TABLE gate01.pass OWNER TO admin_user;

--
-- Name: pass_id_seq; Type: SEQUENCE; Schema: gate01; Owner: admin_user
--

CREATE SEQUENCE gate01.pass_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gate01.pass_id_seq OWNER TO admin_user;

--
-- Name: pass_id_seq; Type: SEQUENCE OWNED BY; Schema: gate01; Owner: admin_user
--

ALTER SEQUENCE gate01.pass_id_seq OWNED BY gate01.pass.id;


--
-- Name: user; Type: TABLE; Schema: gate01; Owner: admin_user
--

CREATE TABLE gate01."user" (
    id integer NOT NULL,
    last_name character varying(32) NOT NULL,
    first_name character varying(32) NOT NULL,
    middle_name character varying(32) NOT NULL,
    phone character varying(20) NOT NULL,
    email character varying(32) NOT NULL,
    address character varying(255) NOT NULL
);


ALTER TABLE gate01."user" OWNER TO admin_user;

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: gate01; Owner: admin_user
--

CREATE SEQUENCE gate01.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gate01.user_id_seq OWNER TO admin_user;

--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: gate01; Owner: admin_user
--

ALTER SEQUENCE gate01.user_id_seq OWNED BY gate01."user".id;


--
-- Name: camera id; Type: DEFAULT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.camera ALTER COLUMN id SET DEFAULT nextval('gate01.camera_id_seq'::regclass);


--
-- Name: event id; Type: DEFAULT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.event ALTER COLUMN id SET DEFAULT nextval('gate01.event_id_seq'::regclass);


--
-- Name: pass id; Type: DEFAULT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.pass ALTER COLUMN id SET DEFAULT nextval('gate01.pass_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01."user" ALTER COLUMN id SET DEFAULT nextval('gate01.user_id_seq'::regclass);


--
-- Data for Name: camera; Type: TABLE DATA; Schema: gate01; Owner: admin_user
--

COPY gate01.camera (id, name) FROM stdin;
1	IN
2	OUT
\.


--
-- Data for Name: event; Type: TABLE DATA; Schema: gate01; Owner: admin_user
--

COPY gate01.event (id, fk_pass, event_time, vehicle_number, fk_camera, photo_url, success, note) FROM stdin;
\.


--
-- Data for Name: pass; Type: TABLE DATA; Schema: gate01; Owner: admin_user
--

COPY gate01.pass (id, fk_user, phone_number, vehicle_number, start_date, end_date, blocked) FROM stdin;
1	1	79261111111	\N	2025-07-31	2025-12-31	f
2	1	79261111112	\N	2024-07-31	2024-12-31	f
4	2	79262222221	\N	2025-07-31	2025-12-31	f
5	2	79262222222	\N	2024-07-31	2024-12-31	f
7	3	79263333331	\N	2025-07-31	2025-12-31	f
8	3	79263333332	\N	2024-07-31	2024-12-31	f
10	1	\N	А111АА111	2025-07-31	2025-12-31	f
11	1	\N	А111АА112	2024-07-31	2024-12-31	f
13	2	\N	А222АА111	2025-07-31	2025-12-31	f
14	2	\N	А222АА112	2024-07-31	2024-12-31	f
16	3	\N	А333АА111	2025-07-31	2025-12-31	f
17	3	\N	А333АА112	2024-07-31	2024-12-31	f
3	1	79261111113	\N	2025-07-31	2025-12-31	t
6	2	79262222223	\N	2025-07-31	2025-12-31	t
9	3	79263333333	\N	2025-07-31	2025-12-31	t
12	1	\N	А111АА113	2025-07-31	2025-12-31	t
15	2	\N	А222АА113	2025-07-31	2025-12-31	t
18	3	\N	А333АА113	2025-07-31	2025-12-31	t
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: gate01; Owner: admin_user
--

COPY gate01."user" (id, last_name, first_name, middle_name, phone, email, address) FROM stdin;
1	Иванов	Иван	Иванович	79261111111	ivan@example.com	1, ул. Лесная
2	Петров	Петр	Петрович	79262222222	peter@example.com	2, ул. Прожекторная
3	Васильев	Василий	Васильевич	79263333333	vasiliy@example.com	3, ул. Березовая
\.


--
-- Name: camera_id_seq; Type: SEQUENCE SET; Schema: gate01; Owner: admin_user
--

SELECT pg_catalog.setval('gate01.camera_id_seq', 1, false);


--
-- Name: event_id_seq; Type: SEQUENCE SET; Schema: gate01; Owner: admin_user
--

SELECT pg_catalog.setval('gate01.event_id_seq', 1, false);


--
-- Name: pass_id_seq; Type: SEQUENCE SET; Schema: gate01; Owner: admin_user
--

SELECT pg_catalog.setval('gate01.pass_id_seq', 18, true);


--
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: gate01; Owner: admin_user
--

SELECT pg_catalog.setval('gate01.user_id_seq', 3, true);


--
-- Name: camera camera_pkey; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.camera
    ADD CONSTRAINT camera_pkey PRIMARY KEY (id);


--
-- Name: event event_pkey; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: pass pass_phone_number_key; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.pass
    ADD CONSTRAINT pass_phone_number_key UNIQUE (phone_number);


--
-- Name: pass pass_pkey; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.pass
    ADD CONSTRAINT pass_pkey PRIMARY KEY (id);


--
-- Name: pass pass_vehicle_number_key; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.pass
    ADD CONSTRAINT pass_vehicle_number_key UNIQUE (vehicle_number);


--
-- Name: user user_phone_key; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01."user"
    ADD CONSTRAINT user_phone_key UNIQUE (phone);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: event event_fk_camera_fkey; Type: FK CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.event
    ADD CONSTRAINT event_fk_camera_fkey FOREIGN KEY (fk_camera) REFERENCES gate01.camera(id);


--
-- Name: event event_fk_pass_fkey; Type: FK CONSTRAINT; Schema: gate01; Owner: admin_user
--

ALTER TABLE ONLY gate01.event
    ADD CONSTRAINT event_fk_pass_fkey FOREIGN KEY (fk_pass) REFERENCES gate01.pass(id);


--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.18 (Ubuntu 14.18-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE postgres;
--
-- Name: postgres; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C.UTF-8';


ALTER DATABASE postgres OWNER TO postgres;

\connect postgres

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

