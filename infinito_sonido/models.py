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
