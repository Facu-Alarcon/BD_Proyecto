# infinito_sonido/forms.py

from django import forms
from .models import Equipo, TipoEquipo



class EquipoForm(forms.ModelForm):
    class Meta:
        model = Equipo
        fields = ['nombre_equipo', 'tipo_equipo', 'estado_equipo', 'cantidad_equipo']
        widgets = {
            'nombre_equipo': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Nombre del equipo',
            }),
            'tipo_equipo': forms.Select(attrs={
                'class': 'form-select',
            }),
            'estado_equipo': forms.Select(attrs={
                'class': 'form-select',
            }),
            'cantidad_equipo': forms.NumberInput(attrs={
                'class': 'form-control',
                'min': 1,
            }),
        }
        labels = {
            'nombre_equipo': 'Nombre del equipo',
            'tipo_equipo': 'Tipo de equipo',
            'estado_equipo': 'Estado',
            'cantidad_equipo': 'Cantidad',
        }

    def clean_cantidad_equipo(self):
        cantidad = self.cleaned_data.get('cantidad_equipo')
        if cantidad is not None and cantidad < 1:
            raise forms.ValidationError("La cantidad debe ser al menos 1.")
        return cantidad


#!Agregado por Aye, para seguir con las tablas que deberian ir primero 
class TipoEquipoForm(forms.ModelForm):
    class Meta:
        model = TipoEquipo
        fields = ['nombre_tipoeq']
        widgets = {
            'nombre_tipoeq': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Nombre del tipo de equipo',
            }),
        }
        labels = {
            'nombre_tipoeq': 'Nombre del tipo de equipo',
        }
        