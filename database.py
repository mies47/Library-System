import psycopg2 as pg
import pandas as pd

db_user = input()
db_password = input()
connection = pg.connect(user=db_user,password=db_password,host="127.0.0.1",port="5432",database="Library")

cursor = connection.cursor()

print("Welcome to my Library")
print("In each page there will be guidlines")
print("Please choose the desired option and enter data")
userLogInfo = ''

while 1:
    print("1-Log in")
    print("2-Sign up")
    option = int(input())

    if option == 1:
        print('Enter userName')
        userName = input()
        print('Enter password')
        password = input()
        cursor.execute("SELECT * FROM login('%s' , '%s');" % (userName , password))
        result = cursor.fetchone()[0]
        if result != 'Password incorrect!!':
            userLogInfo = result
            connection.commit()
            break
        else:
            print(result)
            connection.rollback()
    
    if option == 2:
        print('Enter userName(6 charchter long must only be numbers and letters):')
        userName = input()
        print('Enter password(8 charachter long must include both letters and numbers):')
        password = input()
        print('Enter first name:')
        firstname = input()
        print('Enter last name:')
        lastname = input()
        print('Enter address:')
        address = input()
        print('Enter phone number:')
        phonenumber = input()
        print('Enter account Type among: Normal,Student,Master,Employee,Manager')
        role = input()
        try:
            connection.autocommit = False
            cursor.execute("CALL addAcount('%s' , '%s','%s','%s','%s','%s', '%s');" % (userName , password , firstname , lastname , address , phonenumber , role))
            connection.commit()
            print('Account Added!')
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()
        
while 1:
    print('------------Every One----------')
    print('0-Quit')
    print('1-Get your info')
    print('2-Search Books')
    print('3-Get Books')
    print('4-Return Books')
    print('5-Add to balance')
    print('------------Employee----------')
    print('6-Add new Books')
    print('7-Get successful requests')
    print('8-Get Delayed Books')
    print('9-History of Book')
    print('10-Search all users')
    print('11-Get user Info')
    print('12-See messages')
    print('------------Manager----------')
    print('13-Remove User')

    option = int(input())

    if option == 0:
        cursor.execute("SELECT FROM userQuit('%s');" % userLogInfo)
        connection.commit()
        userLogInfo = ''
        break
    elif option == 1:
        result = pd.read_sql_query("SELECT * FROM getUserInfo('%s');" % userLogInfo , connection)
        result = pd.DataFrame(result)
        print()
        print(result.to_markdown())
        print()
        connection.commit()
    elif option == 2:
        print('Title:')
        title = input()
        print('Author:')
        author = input()
        print('Date Of Print: (YYYY-MM-DD)')
        date = input()
        print('Edition:')
        edition = input()
        if edition == '':
            edition = -1
        else:
            edition = int(edition)
        result = pd.read_sql_query("SELECT * FROM searchBook('%s' , '%s' , %d , '%s');" % (title , author , edition , date) , connection)
        result = pd.DataFrame(result)
        print()
        print(result.to_markdown())
        print()
        connection.commit()
    elif option == 3:
        print('BookID:')
        book_id = int(input())
        print('CoverNum:')
        cover = int(input())
        print('Edition:')
        edition = int(input())
        result = pd.read_sql_query("SELECT * FROM getBook(%d , %d , %d , '%s');" % (book_id , cover , edition , userLogInfo) , connection)
        print(result)
        connection.commit()
    elif option == 4:
        print('BookID:')
        book_id = int(input())
        print('CoverNum:')
        cover = int(input())
        print('Edition:')
        edition = int(input())
        result = pd.read_sql_query("SELECT * FROM takeBackBook(%d , %d , %d , '%s');" % (book_id , cover , edition , userLogInfo) , connection)
        print(result)
        connection.commit()
    elif option == 5:
        print('Balance')
        balance = int(input())
        result = pd.read_sql_query("SELECT * FROM addBalance('%s' , %d);" % (userLogInfo , balance) , connection)
        print(result)
        connection.commit()
    elif option == 6:
        print('BookID:')
        book_id = int(input())
        print('CoverNum:')
        cover = int(input())
        print('Edition:')
        edition = int(input())
        print('Number:')
        number = int(input())
        print('Title:')
        title = input()
        print('Category:UniLearn , Reference , others')
        category = input()
        print('Page Number:')
        pagenum = int(input())
        print('Price:')
        price = int(input())
        print('Author:')
        author = input()
        print('Print Date:')
        print_date = input()
        result = pd.read_sql_query(f"SELECT * FROM addBook({book_id} , {cover}, {edition} , {number} , '{title}' ,'{category}' , {pagenum} , {price} , '{author}' , '{print_date}' , '{userLogInfo}');" , connection)
        print(result)
        connection.commit()
    elif option == 7:
        print('Page:')
        page = int(input())
        try:
            result = pd.read_sql_query("SELECT * FROM successPage('%s' , %d);" % (userLogInfo , page) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()

    elif option == 8:
        try:
            result = pd.read_sql_query("SELECT * FROM delayedBooks('%s');" % (userLogInfo) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()

    elif option == 9:
        try:
            print('BookID:')
            book_id = int(input())
            print('CoverNum:')
            cover = int(input())
            print('Edition:')
            edition = int(input())
            result = pd.read_sql_query("SELECT * FROM bookHistory('%s' ,%d , %d , %d);" % (userLogInfo, book_id , cover , edition) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()        
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()
    
    elif option == 10:
        try:
            print('UserName:')
            userName = input()
            print('LastName:')
            lastname = input()
            print('Page:')
            page = int(input())
            result = pd.read_sql_query("SELECT * FROM searchUser('%s' ,'%s' , '%s' , %d);" % (userLogInfo, userName , lastname , page) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()
    
    elif option == 11:
        try:
            userName = input()
            result = pd.read_sql_query("SELECT * FROM viewUser('%s' , '%s');" % (userLogInfo, userName) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
            result = pd.read_sql_query("SELECT * FROM viewUserHistory('%s' , '%s');" % (userLogInfo, userName) , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()
    
    elif option == 12:
        try:
            result = pd.read_sql_query("SELECT * FROM getMessages('%s');" % userLogInfo , connection)
            result = pd.DataFrame(result)
            print()
            print(result.to_markdown())
            print()
            connection.commit()
        except Exception as e:
            print(str(e).partition('\n')[0])
            connection.rollback()

    elif option == 13:
        userName = input()
        result = pd.read_sql_query("SELECT * FROM deleteUser('%s' , '%s');" % (userLogInfo, userName) , connection)   
        print(result)
        connection.commit()

    else:
        print('INVALID INPUT!') 

cursor.close()
connection.close()