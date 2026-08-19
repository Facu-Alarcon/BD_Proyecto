from django.db import models

'''
Van los modelos de la base datos === TABLAS DE LA BD 
Se lo crea como objetos
'''
class Sueldo(models.Model):
   monto_sueldo = models.DecimalField(max_digits = 10, decimal_places = 2)
   def __str__(self):
        return f'${self.monto_sueldo}'

class Puesto(models.Model):
    nombre_puesto = models.CharField(max_length = 50)
    id_sueldo = models.ForeignKey(Sueldo,on_delete=models.PROTECT)

    def __str__(self):
        return self.nombre_puesto
    
class Empleado(models.Model):
    nombre_emp = models.CharField(max_length=50)
    apellido_emp = models.CharField(max_length=50)
    telefono_emp = models.CharField(max_length=20)
    email_emp = models.EmailField()
    
    def __str__(self):
        return f'{self.nombre_emp} {self.apellido_emp}'

#! facumacaione - agregando clase Usuario y Perfil

class Perfil(models.Model):
    tipo_perfil = models.CharField(max_length=50)

    def __str__(self):
        return self.tipo_perfil


class Usuario(models.Model):
    id_perfil = models.ForeignKey(Perfil, on_delete=models.PROTECT)
    usuario = models.CharField(max_length=50)
    contraseña = models.CharField(max_length=50)

    def __str__(self):
        return self.usuario