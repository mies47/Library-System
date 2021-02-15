CREATE EXTENSION pgcrypto;

CREATE TABLE person(
    userName VARCHAR(30) PRIMARY KEY,
    first_name VARCHAR(20) NOT NULL,
    last_name VARCHAR(20) NOT NULL,
    address VARCHAR(150) NOT NULL ,
    phoneNumber CHAR(11) NOT NULL,
    typeAccount VARCHAR(20) NOT NULL
);

create unique index uk_lower_username on person(lower(userName));

CREATE TABLE account(
    userName VARCHAR(30) PRIMARY KEY ,
    password TEXT NOT NULL ,
    balance INT DEFAULT 0,
    created_date DATE NOT NULL,
    FOREIGN KEY (userName) REFERENCES person (userName) ON DELETE CASCADE ,
    CHECK ( balance >= 0 )
);

CREATE TABLE logUsers(
    logInfo TEXT PRIMARY KEY ,
    userName VARCHAR(30),
    FOREIGN KEY (userName) REFERENCES person (userName) ON DELETE CASCADE
);

CREATE TABLE book(
    book_id BIGINT,
    cover_num INT,
    edition INT,
    number INT,
    title VARCHAR(20) NOT NULL ,
    category VARCHAR(20) NOT NULL ,
    number_of_pages INT NOT NULL ,
    price INT NOT NULL ,
    author VARCHAR(20) NOT NULL ,
    printed_date DATE NOT NULL ,
    PRIMARY KEY (book_id, cover_num, edition),
    CHECK ( price >= 0 AND number >= 0 AND number_of_pages >= 0)
);

CREATE TABLE borrow_history(
    borrowId SERIAL PRIMARY KEY ,
    userName VARCHAR(30),
    book_id BIGINT,
    cover_num INT,
    edition INT,
    returnDate DATE ,
    realReturn DATE,
    takenDate DATE NOT NULL ,
    result varchar(30) NOT NULL ,
    FOREIGN KEY (userName) REFERENCES person(userName) ON DELETE CASCADE ,
    FOREIGN KEY (book_id , cover_num , edition) REFERENCES book (book_id , cover_num , edition)
);

CREATE TABLE success_history(
    successId SERIAL PRIMARY KEY ,
    message VARCHAR(250)
);

CREATE PROCEDURE addAcount(
    userName varchar,
    enterpassWord varchar,
    first_name varchar,
    last_name varchar,
    address varchar,
    phoneNumber varchar,
    typeAccount varchar
)
language plpgsql
as $$
BEGIN
        IF userName ~ '^[a-zA-Z0-9]+$' AND length(userName) >= 6 THEN
            INSERT INTO person (userName,first_name, last_name, address, phoneNumber , typeAccount)
            VALUES (addAcount.userName,addAcount.first_name,addAcount.last_name,addAcount.address,addAcount.phoneNumber, addAcount.typeAccount);
                IF (NOT enterpassWord ~ '^(?!.*[0-9])') AND (NOT enterpassWord ~ '^(?!.*[a-z A-Z])') AND length(enterpassWord) >= 8 THEN
                    INSERT INTO account (USERNAME, PASSWORD, CREATED_DATE)
                    VALUES (addAcount.userName,crypt(addAcount.enterpassword , gen_salt('MD5')),CURRENT_DATE);
                ELSE
                    RAISE EXCEPTION 'Password not valid';
                END IF;
        ELSE
            RAISE EXCEPTION 'UserName not valid';
        END IF;

        EXCEPTION WHEN SQLSTATE '23000' THEN
            RAISE EXCEPTION 'userName exists!';

END;$$;

CREATE FUNCTION login(
    userName varchar,
    password text
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    savedPass text;
BEGIN
    SELECT account.password
    INTO savedPass
    FROM account
    WHERE account.userName = login.userName;
    IF crypt( login.password, savedPass) = savedPass THEN
        savedPass = md5(userName || password || CURRENT_TIMESTAMP);
        INSERT INTO logUsers (logInfo, userName)
        VALUES (savedPass , login.userName);
        RETURN savedPass;
    ELSE
        RETURN 'Password incorrect!!';
    END IF;
END;$$;

CREATE FUNCTION addBalance(
userLogData TEXT,
balance INT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    lastBalance INT;
BEGIN
    IF addBalance.balance < 0 THEN RETURN 'NOT VALID'; END IF;
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE userLogData = logInfo;

    SELECT account.balance
    INTO lastBalance
    FROM account
    WHERE account.userName = selectedUserName;

    UPDATE account
    SET balance = lastBalance + addBalance.balance
    WHERE account.userName = selectedUserName;
    RETURN 'Added';

END;$$;

CREATE FUNCTION addBook(
    book_id BIGINT,
    cover_num INT,
    edition INT,
    number INT,
    title VARCHAR ,
    category VARCHAR ,
    number_of_pages INT ,
    price INT,
    author VARCHAR,
    printed_date VARCHAR,
    user_log TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
    last_number INT;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN RETURN 'NOT ALLOWED';END IF;
    IF (addBook.book_id , addBook.cover_num , addBook.edition) IN (SELECT book.book_id , book.cover_num , book.edition FROM book)
        THEN
            SELECT book.number
            INTO last_number
            FROM book
            WHERE addBook.book_id = book.book_id AND addBook.cover_num = book.cover_num AND addBook.edition = book.edition;
            UPDATE book
            SET number = last_number + addBook.number
            WHERE addBook.book_id = book.book_id AND addBook.cover_num = book.cover_num AND addBook.edition = book.edition;
            RETURN 'OLD BOOK INCREASED';
        ELSE
            INSERT INTO book (book_id, cover_num, edition, number, title, category, number_of_pages, price, author , printed_date)
            VALUES (addBook.book_id , addBook.cover_num , addBook.edition , addBook.number , addBook.title , addBook.category , addBook.number_of_pages , addBook.price , addBook.author , CAST(addBook.printed_date AS DATE));
            RETURN 'NEW BOOK ADDED';
    END IF;
END;$$;

CREATE FUNCTION searchBook(
    book_name VARCHAR,
    author_name VARCHAR,
    edition_num INT,
    e_printed_date VARCHAR
)
RETURNS TABLE(
    book_id BIGINT,
    cover_num INT,
    edition INT,
    number INT,
    title VARCHAR(20) ,
    category VARCHAR(20) ,
    number_of_pages INT ,
    price INT ,
    author VARCHAR(20) ,
    printed_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    name_entered BOOLEAN;
    author_entered BOOLEAN;
    edition_entered BOOLEAN;
    date_entered BOOLEAN;
BEGIN
    name_entered = TRUE;
    author_entered = TRUE;
    edition_entered = TRUE;
    date_entered = TRUE;
    IF searchBook.book_name = '' THEN name_entered = FALSE; END IF;
    IF searchBook.author_name = '' THEN author_entered = FALSE; END IF;
    IF searchBook.edition_num = -1 THEN edition_entered = FALSE; END IF;
    IF searchBook.e_printed_date = '' THEN date_entered = FALSE; END IF;

    RETURN QUERY SELECT *
            FROM book
            WHERE (NOT name_entered OR book.title LIKE ('%' || searchBook.book_name || '%' ))
              AND (NOT author_entered OR book.author LIKE ('%' || searchBook.author_name || '%' ))
              AND (NOT edition_entered OR searchBook.edition_num = book.edition)
              AND (NOT date_entered OR TO_DATE(searchBook.e_printed_date , 'YYYY-MM-DD') = book.printed_date);

END;$$;

CREATE FUNCTION getBook(
    book_id BIGINT,
    cover_num INT,
    edition INT,
    user_log TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
    selected_cat VARCHAR;
    book_price INT;
    user_balance INT;
    avail INT;
    delay_num INT;
    last_delayed DATE;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;


    SELECT category , number , price
    INTO selected_cat , avail , book_price
    FROM book
    WHERE getBook.book_id = book.book_id AND getBook.cover_num = book.cover_num AND getBook.edition = book.edition;

    IF selected_role = 'Normal' AND (selected_cat = 'UniLearn' OR selected_cat = 'Reference') THEN RETURN 'NOT ALLOWED'; END IF;
    IF selected_role = 'Student' AND selected_cat = 'Reference' THEN RETURN 'NOT ALLOWED'; END IF;

    IF selectedUserName IN (SELECT userName FROM borrow_history) THEN
        SELECT count(*)
        INTO delay_num
        FROM borrow_history
        WHERE selectedUserName = userName  AND result = 'SUCCESS' AND realReturn IS NOT NULL AND CURRENT_DATE - INTERVAL '2' MONTH <= realReturn AND realReturn > returnDate;

        SELECT MAX(realReturn)
        INTO last_delayed
        FROM borrow_history
        WHERE selectedUserName = userName AND result = 'SUCCESS' AND realReturn IS NOT NULL AND realReturn > returnDate;
        IF delay_num >= 4 AND CURRENT_DATE <= last_delayed + INTERVAL '1' MONTH
        THEN
            INSERT INTO borrow_history (userName, book_id, cover_num, edition, returnDate, realReturn, takenDate, result)
            VALUES (selectedUserName , getBook.book_id , getBook.cover_num , getBook.edition , NULL  , NULL , CURRENT_DATE , 'EXCLUSION');
            RETURN 'DECLINED FOR DELAY MORE THAN 4 TIMES IN THE LAST TWO MONTH';
        END IF;
    END IF;

    SELECT balance
    INTO user_balance
    FROM account
    WHERE account.userName = selectedUserName;

    IF CAST((book_price * 5 / 100) AS INT) > user_balance THEN
        INSERT INTO borrow_history (userName, book_id, cover_num, edition, returnDate, realReturn, takenDate, result)
        VALUES (selectedUserName , getBook.book_id , getBook.cover_num , getBook.edition , NULL  , NULL, CURRENT_DATE  , 'BALANCE');
        RETURN 'DECLINED FOR LACK OF BALANCE';
    END IF;

    IF avail <= 0 THEN
        INSERT INTO borrow_history (userName, book_id, cover_num, edition, returnDate, realReturn, takenDate, result)
        VALUES (selectedUserName , getBook.book_id , getBook.cover_num , getBook.edition , NULL  , NULL, CURRENT_DATE  , 'INVENTORY');
        RETURN 'DECLINED FOR LACK OF INVENTORY';
    END IF;

    INSERT INTO borrow_history (userName, book_id, cover_num, edition, returnDate, realReturn, takenDate, result)
    VALUES (selectedUserName , getBook.book_id , getBook.cover_num , getBook.edition , CURRENT_DATE + INTERVAL '7' DAY , NULL, CURRENT_DATE  , 'SUCCESS');
    UPDATE book
    SET number = avail - 1
    WHERE getBook.book_id = book.book_id AND getBook.cover_num = book.cover_num AND getBook.edition = book.edition;
    UPDATE account
    SET balance = user_balance - CAST((book_price * 5 / 100) AS INT)
    WHERE account.userName = selectedUserName;

    RETURN 'SUCCESS';

END;$$;

CREATE FUNCTION takeBackBook(
    book_id BIGINT,
    cover_num INT,
    edition INT,
    user_log TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selectedReturn DATE;
    avail INT;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    UPDATE borrow_history
    SET realReturn = CURRENT_DATE
    WHERE selectedUserName = borrow_history.userName AND takeBackBook.book_id = borrow_history.book_id AND takeBackBook.cover_num = borrow_history.cover_num AND takeBackBook.edition = borrow_history.edition;

    SELECT returnDate
    INTO selectedReturn
    FROM borrow_history
    WHERE selectedUserName = borrow_history.userName AND takeBackBook.book_id = borrow_history.book_id AND takeBackBook.cover_num = borrow_history.cover_num AND takeBackBook.edition = borrow_history.edition;

    SELECT number
    INTO avail
    FROM book
    WHERE takeBackBook.book_id = book.book_id AND takeBackBook.cover_num = book.cover_num AND takeBackBook.edition = book.edition;

    UPDATE book
    SET number = avail + 1
    WHERE takeBackBook.book_id = book.book_id AND takeBackBook.cover_num = book.cover_num AND takeBackBook.edition = book.edition;

    RETURN 'YOU HAVE RETURNED THE BOOK';

END;$$;


CREATE FUNCTION newBookTrigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.result = 'SUCCESS' THEN
        INSERT INTO success_history (message)
        VALUES ('IN ' || CURRENT_DATE || ' USER ' || NEW.userName || ' TOOK BOOK ' || NEW.book_id || ' ' || NEW.cover_num || ' ' || NEW.edition);
    END IF;

    RETURN NEW;
END;$$;

CREATE TRIGGER newBook
    AFTER INSERT
    ON borrow_history
    FOR EACH ROW
    EXECUTE PROCEDURE newBookTrigger();

CREATE FUNCTION getBackTrigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.returnDate < NEW.realReturn THEN
        INSERT INTO success_history (message)
        VALUES ('USER ' || NEW.userName || 'RETURNED WITH DELAY ON ' || NEW.realReturn);
    ELSE
        INSERT INTO success_history (message)
        VALUES ('USER ' || NEW.userName || 'RETURNED WITHOUT DELAY ON ' || NEW.realReturn);
    END IF;

    RETURN NEW;
END;$$;

CREATE TRIGGER getBack
    AFTER UPDATE
    ON borrow_history
    FOR EACH ROW
    EXECUTE PROCEDURE getBackTrigger();

CREATE FUNCTION getUserInfo(
    user_log TEXT
)
RETURNS TABLE(
    o_userName VARCHAR,
    o_first_name VARCHAR,
    o_last_name VARCHAR,
    o_address VARCHAR ,
    o_phoneNumber CHAR,
    o_typeAccount VARCHAR,
    o2_userName VARCHAR,
    o_password TEXT,
    o_balance INT,
    o_created_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    RETURN QUERY (SELECT  * FROM person INNER JOIN account ON person.userName = account.userName WHERE person.userName = selectedUserName);
END;$$;

CREATE FUNCTION successPage(
    user_log TEXT,
    page INT
)
RETURNS TABLE(
    o_borrowId INT ,
    o_userName VARCHAR,
    o_book_id BIGINT,
    o_cover_num INT,
    o_edition INT,
    o_returnDate DATE ,
    o_realReturn DATE,
    o_takenDate DATE ,
    o_result varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN
        RAISE EXCEPTION 'NOT ALLOWED';
    END IF;

    RETURN QUERY (SELECT *
    FROM borrow_history
    WHERE borrow_history.result = 'SUCCESS'
    ORDER BY borrow_history.takenDate
    LIMIT 5 OFFSET 5 * (page - 1));

END;$$;

CREATE FUNCTION searchUser(
    user_log VARCHAR,
    i_userName VARCHAR,
    i_last_name VARCHAR,
    page INT
)
RETURNS TABLE(
    o_userName VARCHAR,
    o_first_name VARCHAR,
    o_last_name VARCHAR,
    o_address VARCHAR,
    o_phoneNumber CHAR,
    o_typeAccount VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
    username_ent BOOLEAN;
    last_name_ent BOOLEAN;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN
        RAISE EXCEPTION 'NOT ALLOWED';
    ELSE
        IF i_userName = '' THEN username_ent = FALSE; END IF;
        IF i_last_name = '' THEN last_name_ent = FALSE; END IF;

        RETURN QUERY ( SELECT * FROM person
                       WHERE (NOT username_ent OR person.userName LIKE ('%' || i_userName || '%'))
                         AND (NOT last_name_ent OR person.last_name LIKE ('%' || i_last_name || '%'))
                       ORDER BY person.last_name
                       LIMIT 5 OFFSET (page - 1) * 5);
    END IF;


END;$$;

CREATE FUNCTION viewUser(
    user_log TEXT,
    i_userName VARCHAR
)
RETURNS TABLE(
    o_userName VARCHAR,
    o_first_name VARCHAR,
    o_last_name VARCHAR,
    o_address VARCHAR ,
    o_phoneNumber CHAR,
    o_typeAccount VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN
        RAISE EXCEPTION 'NOT ALLOWED';
    ELSE
        RETURN QUERY
            (SELECT *
            FROM person
            WHERE person.userName = i_userName);
    END IF;

END;$$;

CREATE FUNCTION viewUserHistory(
    user_log TEXT,
    i_userName VARCHAR
)
RETURNS TABLE(
    o_borrowId INT,
    o_userName VARCHAR,
    o_book_id BIGINT,
    o_cover_num INT,
    o_edition INT,
    o_returnDate DATE ,
    o_realReturn DATE,
    o_takenDate DATE ,
    o_result varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN
        RAISE EXCEPTION 'NOT ALLOWED';
    ELSE
        RETURN QUERY
            (SELECT *
            FROM borrow_history
            WHERE borrow_history.userName = i_userName
            ORDER BY borrow_history.takenDate);
    END IF;

END;$$;

CREATE FUNCTION delayedBooks(
    user_log TEXT
)
RETURNS TABLE(
    o_book_id BIGINT,
    o_cover_num INT,
    o_edition INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN
        RAISE EXCEPTION 'NOT ALLOWED';
    ELSE
        RETURN QUERY (
            SELECT borrow_history.book_id , borrow_history.cover_num , borrow_history.edition
            FROM borrow_history
            WHERE borrow_history.result = 'SUCCESS' AND
                  ((borrow_history.returnDate < CURRENT_DATE AND borrow_history.realReturn IS NULL) OR
                  (borrow_history.realReturn > borrow_history.returnDate))
            ORDER BY (borrow_history.realReturn - borrow_history.returnDate) DESC
        );
    END IF;
END;$$;

CREATE FUNCTION deleteUser(
    user_log TEXT,
    in_username VARCHAR
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Manager' THEN RETURN 'NOT ALLOWED';END IF;

    DELETE FROM person
    WHERE person.userName = in_username;

    RETURN 'USER DELETED';

END;$$;

CREATE FUNCTION bookHistory(
    user_log TEXT,
    i_book_id BIGINT,
    i_cover_num INT,
    i_edition INT
)
RETURNS TABLE(
    o_get_date DATE,
    o_real_return DATE,
    o_username VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedUserName VARCHAR;
    selected_role VARCHAR;
BEGIN
    SELECT userName
    INTO selectedUserName
    FROM logUsers
    WHERE user_log = logInfo;

    SELECT typeAccount
    INTO selected_role
    FROM person
    WHERE selectedUserName = userName;

    IF selected_role <> 'Employee' AND selected_role <> 'Manager' THEN RAISE EXCEPTION 'NOT ALLOWED';END IF;

    RETURN QUERY (
        SELECT takenDate , realReturn , userName
        FROM borrow_history
        WHERE borrow_history.result = 'SUCCESS' AND i_book_id = borrow_history.book_id AND i_cover_num = borrow_history.cover_num AND i_edition = borrow_history.edition
        ORDER BY takenDate
    );
END;$$;

CREATE FUNCTION userQuit(
    user_log TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM logUsers
    WHERE logInfo = user_log;
END;$$;

CREATE FUNCTION getMessages(
    user_log TEXT
)
RETURNS TABLE(
    o_message VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    selectedType VARCHAR;
BEGIN
    SELECT typeAccount
    INTO selectedType
    FROM logusers INNER JOIN person p on logUsers.userName = p.userName
    WHERE logUsers.logInfo = user_log;

    IF selectedType <> 'Employee' AND selectedType <> 'Manager' THEN RAISE EXCEPTION 'NOT ALLOWED'; END IF;

    RETURN QUERY (SELECT message FROM success_history);
END;$$;