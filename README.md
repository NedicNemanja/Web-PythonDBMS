# Web-PythonDBMS
Three layer application for managing a data base. The first layer is a web based user interface, underneath it is the application implemented in python and the final layer is the "movies" data base.

# Set up MySQL server for "movies" database (for debian based Linux)
To install mysql server in case you have not already:
```
sudo apt-get install mysql-server mysql-client
```
Give a password for the root account that manages the server.
Connect to mqsql using the password that you just gave:
```
mysql -r root -p
```
A prompt will open if all went well. Run:
```
create database movies;
grant all on movies.* 'actor'@'%' identified by 'actor';
flush privileges;
quit
```
Now go to the directory that contains the movie.sql file and import using:
```
mysql -u root -p movies < movies.sql
```
Connect to client to check that that the DB is set up correctly:
```
mysql -u actor -p
```
Password is: actor
```
show databases;
```
Now open up you my sql workbench. Choose Edit a new conenction (MySQL connections+):
```
Connection name: movies
Hostname: (leave this as is)
Username: actor
```
Press ok. Wehn you select the conenction movies you will be asked for the pasword of the actor user.
You can run queries now.

# Set up the application
Go to the file settings.py and fill the "mysql_user" and  "mysql_passwd" field with the username(probably root) and the password you gave when setting up the db server.
Now run the website.py with the command:
```
python3 website.py
```
Note: Python 3 is required. On your system you might be able to run with "python website.py" as well.

![alt text](https://github.com/NedicNemanja/Web-PythonDBMS/blob/master/SqlDB/Capture.PNG)
