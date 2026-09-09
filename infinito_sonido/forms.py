# forms.py
from django import forms
from django.contrib.auth.hashers import make_password
from .models import Equipos, Perfiles, Usuarios, Permisos

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


class BootstrapFormMixin:
    """Aplica clases de Bootstrap a los widgets, igual que en EquiposForm."""

    def _aplicar_estilos(self):
        for field in self.fields.values():
            if isinstance(field.widget, (forms.Select, forms.SelectMultiple)):
                field.widget.attrs.update({'class': 'form-select'})
            elif isinstance(field.widget, forms.CheckboxInput):
                field.widget.attrs.update({'class': 'form-check-input'})
            else:
                field.widget.attrs.update({'class': 'form-control'})


class PerfilesForm(BootstrapFormMixin, forms.ModelForm):
    class Meta:
        model = Perfiles
        fields = '__all__'
        labels = {
            'tipo_perfil': 'Nombre del Perfil',
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._aplicar_estilos()


class PermisosForm(BootstrapFormMixin, forms.ModelForm):
    class Meta:
        model = Permisos
        fields = '__all__'
        labels = {
            'nombre_permiso': 'Nombre del Permiso',
            'descripcion_permiso': 'Descripción',
            'estado_permiso': 'Activo',
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._aplicar_estilos()


class UsuariosForm(BootstrapFormMixin, forms.ModelForm):
    contraseña = forms.CharField(
        label='Contraseña',
        widget=forms.PasswordInput(render_value=False),
        required=False,
        help_text='Al editar, dejar en blanco para mantener la contraseña actual.',
    )

    class Meta:
        model = Usuarios
        fields = ['id_perfil', 'usuario', 'contraseña']
        labels = {
            'id_perfil': 'Perfil',
            'usuario': 'Nombre de usuario',
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._aplicar_estilos()
        # Solo es obligatoria al crear un usuario nuevo
        self.fields['contraseña'].required = not self.instance.pk

    def clean_contraseña(self):
        password = self.cleaned_data.get('contraseña')
        if not password:
            if self.instance.pk:
                # Edición sin cambio de contraseña: se conserva el hash actual
                return self.instance.contraseña
            raise forms.ValidationError('La contraseña es obligatoria.')
        return make_password(password)