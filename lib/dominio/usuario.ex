defmodule Usuario do
  @moduledoc """
  Estructura de un usuario del sistema (ciudadano, voluntario, coordinador o administrador).
  La contraseña nunca se guarda: se guarda su hash.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct usuario: "",
            hash_contrasena: "",
            nombre_completo: "",
            tipo: "ciudadano",
            zona: "",
            fecha_registro: ""

  @doc """
  Crea un usuario nuevo. Las validaciones las hace antes el GenServer `Usuarios`.

  ## Parámetros
    - usuario, contrasena, nombre_completo, tipo, zona, fecha_registro (textos)

  ## Retorna
    - `%Usuario{}` con el hash de la contraseña
  """
  def crear(usuario, contrasena, nombre_completo, tipo, zona, fecha_registro) do
    %Usuario{
      usuario: usuario,
      hash_contrasena: calcular_hash(contrasena),
      nombre_completo: nombre_completo,
      tipo: tipo,
      zona: zona,
      fecha_registro: fecha_registro
    }
  end

  @doc """
  Calcula el hash SHA-256 de una contraseña.

  Un hash es una "huella" del texto: el mismo texto siempre da la misma huella,
  pero con la huella no se puede reconstruir el texto. Por eso se guarda la huella
  y, para validar, se compara la huella de lo que escribe el usuario.
  (`:crypto` es un módulo de Erlang; NO visto en clase, lo pide la seguridad del sistema.)
  """
  def calcular_hash(contrasena) do
    :crypto.hash(:sha256, contrasena)
    |> Base.encode16()
  end

  @doc """
  Retorna true si la contraseña escrita corresponde al hash guardado.
  """
  def contrasena_correcta?(%Usuario{hash_contrasena: hash}, contrasena) do
    calcular_hash(contrasena) == hash
  end

  defimpl String.Chars, for: Usuario do
    def to_string(u) do
      "#{u.usuario} - #{u.nombre_completo} (#{u.tipo}, zona #{u.zona}), registrado #{u.fecha_registro}"
    end
  end
end
