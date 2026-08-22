# forms.py
from django import forms
from .models import Equipos

class EquiposForm(forms.ModelForm):
    class Meta:
        model = Equipos
        fields = '__all__'
        labels = {
            'nombre_equipo': 'Nombre del Equipo',
            'id_tipoeq': 'Tipo de Equipo',
            'estado_equipo': 'Estado del Equipo',
            'cantidad_equipo': 'Cantidad en Stock',
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Asignación automática de clases CSS de Bootstrap según el tipo de widget
        for field_name, field in self.fields.items():
            if isinstance(field.widget, forms.Select):
                field.widget.attrs.update({'class': 'form-select'})
            else:
                field.widget.attrs.update({'class': 'form-control'})