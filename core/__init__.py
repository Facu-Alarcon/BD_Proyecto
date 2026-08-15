# Hacemos que PyMySQL se comporte como el conector MySQLdb que espera Django.
# Esto permite usar el motor 'django.db.backends.mysql' sin compilar nada.
import pymysql

pymysql.install_as_MySQLdb()
