defmodule Neotomex.ExGrammar do
  @moduledoc """
  ## Neotomex.ExGrammar

  ExGrammar provides an interface for defining a PEG from within an
  Elixir module.

  For example:

      defmodule Number do
        use Neotomex.ExGrammar

        @root true
        define :root, "[0-9]+" do
          xs when is_list(xs) -> Enum.join(xs) |> String.to_integer
        end
      end

      Number.parse("42") = 42

  Check the `examples/` folder for slightly more useful examples
  of grammar specifications via `ExGrammar`.

  By default, the grammar is validated on compile. To disable validation,
  add `@validate true` to the module.


  ## Definitions

  A grammar consists of a set of definitions with optional
  transformation functions, and a pointer to the root
  definition. Using the `ExGrammar` interface, a definition
  is specified using the `define` macro.

  Here are some example usages of `define`:


      # No transformation
      define name, expression

      # With transformation
      define name, expression do
        match -> match
      end

      # With a more complex transformation
      # (yup, you could just reduce the list, but that doesn't make the point :)
      define name, expression do
        [x] ->
          String.to_integer(x)
        [x, y] when is_binary(x) and is_binary(y) ->
          String.to_integer(x) + String.to_integer(y)
      end

  The root rule must be labeled via `@root true`.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Neotomex.ExGrammar, only: :macros
      @before_compile Neotomex.ExGrammar

      @validate true
      @root false

      @_root_def nil
      @_neotomex_definitions %{}
    end
  end


  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      if @_root_def == nil do
        throw {:error, :no_root}
      end

      @_neotomex_grammar Neotomex.Grammar.new(@_root_def, @_neotomex_definitions)
      if @validate do
        case Neotomex.Grammar.validate(@_neotomex_grammar) do
          :ok ->
            :ok
          otherwise ->
            throw {:error, {:validation, otherwise}}
        end
      end

      def parse(input) do
        case Neotomex.Grammar.parse(unquote(Macro.escape(@_neotomex_grammar)),
                                    input) do
          {:ok, result, ""} ->
            {:ok, result}
          otherwise ->
            otherwise
        end
      end

      def parse!(input) do
        case Neotomex.Grammar.parse(unquote(Macro.escape(@_neotomex_grammar)),
                                    input) do
          {:ok, result, ""} ->
            result
          otherwise ->
            throw otherwise
        end
      end
    end
  end


  @doc """
  Create a new definition for the module's grammar.
  """
  defmacro define(identifier, expr, body \\ nil) do
    quote bind_quoted: [identifier: identifier,
                        def_name: identifier_to_name(identifier),
                        neo_expr: Macro.escape(parse_expression(expr)),
                        branches: Macro.escape(body_to_branches(body))] do
      if @root do
        if @_root_def == nil do
          @root false
          @_root_def identifier
        else
          throw {:error, :more_than_one_root}
        end
      end

      # Add the new definition with transform, when applicable
      transform = if branches != [], do: {:transform, {__ENV__.module, def_name}}
      @_neotomex_definitions Dict.put(@_neotomex_definitions,
                                      identifier,
                                      {neo_expr, transform})
      for {{args, guards}, body} <- branches do
        def unquote(def_name)(unquote(args)) when unquote(guards) do
          unquote(body)
        end
      end
    end
  end


  ## Private functions

  # Wraps the Neotomex parse_expression function's return values
  defp parse_expression(expr) do
    case Neotomex.PEG.parse_expression(expr) do
      :mismatch ->
        throw {:error, :bad_expression}
      {:ok, expr} ->
        expr
    end
  end


  # Returns the definition name for a given identifier
  defp identifier_to_name(identifier) do
    :"_transform_#{Atom.to_string(identifier)}"
  end


  # Convert a `define` body to [{{args, guards}, body}, ...], or [] for a nil body
  defp body_to_branches(nil), do: []
  defp body_to_branches(body) do
    for {:->, _, [[branch_head], branch_body]} <- body[:do] do
      {split_head(branch_head), branch_body}
    end
  end


  # Split a `define` head into {args, guards}
  @doc false
  defp split_head({:when, _, [arg, guards]}) do
    {arg, guards}
  end

  defp split_head(arg), do: {arg, true}
end